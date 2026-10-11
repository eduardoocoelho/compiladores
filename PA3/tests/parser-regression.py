#!/usr/bin/env python3
"""Testes do parser com expectativas de AST e comparação oficial."""
import os
from pathlib import Path
import re
import subprocess
import tempfile
import unittest

PROJECT = Path(__file__).resolve().parents[1]
COOL = Path(os.environ.get("COOL_HOME", "/var/tmp/cool"))
REFERENCE = Path(os.environ.get("REFERENCE_PARSER", str(COOL / "lib/.x86_64/parser")))
LEXER = Path(os.environ.get("REFERENCE_LEXER", str(COOL / "lib/.x86_64/lexer")))


def run(command, **kwargs):
    return subprocess.run([str(x) for x in command], cwd=PROJECT,
                          text=True, capture_output=True, timeout=15, **kwargs)


def normalized(ast):
    # Apagar somente localização; preservar símbolos, tipos, indentação e ordem.
    return "\n".join(line for line in ast.splitlines()
                     if not re.fullmatch(r"\s*#\d+", line))


def expression_shape(ast):
    """Lê a árvore serializada por indentação e retorna a expressão de main."""
    roots, stack = [], []
    for line in ast.splitlines():
        value = line.strip()
        if not value or value.startswith(("#", ":")) or value in ("(", ")"):
            continue
        depth = len(line) - len(line.lstrip())
        # Após imprimir um filho, o dump pode voltar aos campos do pai
        # (por exemplo o nome do método após o receptor de dispatch).
        while stack and stack[-1][0] >= depth:
            stack.pop()
        if value.startswith("_"):
            node = [value[1:], [], []]
            (stack[-1][1][2] if stack else roots).append(node)
            stack.append((depth, node))
        else:
            stack[-1][1][1].append(value)

    def sexpr(node):
        return "(" + " ".join([node[0], *node[1], *(sexpr(n) for n in node[2])]) + ")"

    for klass in roots[0][2]:
        for feature in klass[2]:
            if feature[0] == "method" and feature[1][0] == "main":
                return sexpr(feature[2][-1])
    raise AssertionError("AST sem método main")


# Precedência/associatividade errada altera estas árvores esperadas.
SHAPES = [
    ("1 + 2 * 3", "(plus (int 1) (mul (int 2) (int 3)))"),
    ("(1 + 2) * 3", "(mul (plus (int 1) (int 2)) (int 3))"),
    ("9 - 5 - 2", "(sub (sub (int 9) (int 5)) (int 2))"),
    ("24 / 3 / 2", "(divide (divide (int 24) (int 3)) (int 2))"),
    ("a <- b <- 3", "(assign a (assign b (int 3)))"),
    ("not 1 < 2", "(comp (lt (int 1) (int 2)))"),
    ("not not true", "(comp (comp (bool 1)))"),
    ("~1 * 2", "(mul (neg (int 1)) (int 2))"),
    ("~~1", "(neg (neg (int 1)))"),
    ("isvoid x + 1", "(plus (isvoid (object x)) (int 1))"),
    ("isvoid ~x", "(isvoid (neg (object x)))"),
    ("~x.f()", "(neg (dispatch f (object x)))"),
    ("f(1, 2)", "(dispatch f (object self) (int 1) (int 2))"),
    ("x@A.f().g()", "(dispatch g (static_dispatch A f (object x)))"),
    ("let x : Int in x + 2 * 3", "(let x Int (no_expr) (plus (object x) (mul (int 2) (int 3))))"),
    ("1 + let x : Int in x + 2", "(plus (int 1) (let x Int (no_expr) (plus (object x) (int 2))))"),
    ("let x : Int <- 1, y : Int <- x in y", "(let x Int (int 1) (let y Int (object x) (object y)))"),
    ("let x : Int <- let y : Int in y in x", "(let x Int (let y Int (no_expr) (object y)) (object x))"),
    ("let x : Int in x <- 2 + 3", "(let x Int (no_expr) (assign x (plus (int 2) (int 3))))"),
    ("(let x : Int in x) + 2", "(plus (let x Int (no_expr) (object x)) (int 2))"),
    ("{ 1; 2; }", "(block (int 1) (int 2))"),
    ("case x of a : A => 1; b : B => 2; esac", "(typcase (object x) (branch a A (int 1)) (branch b B (int 2)))"),
    ("if true then 1 else 2 fi + 3", "(plus (cond (bool 1) (int 1) (int 2)) (int 3))"),
    ("while false loop 1 pool", "(loop (bool 0) (int 1))"),
    ("new SELF_TYPE", "(new SELF_TYPE)"),
    ("(1 < 2) = true", "(eq (lt (int 1) (int 2)) (bool 1))"),
]

INVALID = [
    "", "class a {};", "class A inherits b {};", "class A {}",
    "class A { ; };", "class A { X : Int; };", "class A { x Int; };",
    "class A { f(x:Int,) : Int { 1 }; };",
    "class A { f(X:Int) : Int { 1 }; };",
    "class A { f():Int { 1; }; };", "class A { f():Int { {} }; };",
    "class A { f():Int { { 1 } }; };",
    "class A { f():Int { f(1,) }; };", "class A { f():Int { f(,1) }; };",
    "class A { f():Int { (x) <- 1 }; };",
    "class A { f():Int { if true then 1 fi }; };",
    "class A { f():Int { while true 1 pool }; };",
    "class A { f():Int { case x of esac }; };",
    "class A { f():Int { case x of a:A => 1 esac }; };",
    "class A { f():Int { let in 1 }; };",
    "class A { f():Int { let x:Int, in x }; };",
    "class A { f():Int { new x }; };",
    "class A { f():Int { 1 < 2 < 3 }; };",
    "class A { f():Int { 1 <= 2 = 3 }; };",
    "class A { f():Int { 1 = 2 < 3 }; };",
    "class A { f():Int { -1 }; };", "class A { f():Int { 1 > 2 }; };",
    "class A { f():Int { # }; };",
    "class A { f():Int { \"unterminated\n }; };",
    "class A { (* EOF", "class A { f():Int { (1 +",
]


class ParserTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        build = run(["make", "parser", "lexer", "semant", "cgen"])
        if build.returncode:
            raise AssertionError(build.stdout + build.stderr)
        for executable in (LEXER, REFERENCE, COOL / "bin/spim"):
            if not os.access(executable, os.X_OK):
                raise AssertionError(f"Dependência ausente: {executable}")
        cls.temp = tempfile.TemporaryDirectory(prefix="pa3-tests-")
        cls.work = Path(cls.temp.name)

    @classmethod
    def tearDownClass(cls):
        cls.temp.cleanup()

    def parse(self, path, parser=None):
        tokens = run([LEXER, path])
        self.assertEqual(tokens.returncode, 0, tokens.stderr)
        return run([parser or PROJECT / "parser"], input=tokens.stdout)

    def source(self, source):
        path = self.work / "input.cl"
        path.write_text(source)
        return path

    def assert_valid(self, path):
        actual = self.parse(path)
        self.assertEqual(actual.returncode, 0, actual.stderr)
        self.assertEqual(actual.stderr, "")
        expected = self.parse(path, REFERENCE)
        self.assertEqual(expected.returncode, 0, expected.stderr)
        self.assertEqual(normalized(actual.stdout), normalized(expected.stdout))
        return actual.stdout

    def test_minimal_classes(self):
        self.assert_valid(self.source("class Empty {}; class Main inherits IO {};"))

    def test_all_constructions(self):
        self.assert_valid(PROJECT / "good.cl")

    def test_expression_shapes(self):
        for expression, expected in SHAPES:
            with self.subTest(expression=expression):
                ast = self.assert_valid(self.source(f"class Main {{ main():Object {{ {expression} }}; }};"))
                self.assertEqual(expression_shape(ast), expected)

    def test_invalid_syntax(self):
        for source in INVALID:
            with self.subTest(source=source):
                path = self.source(source)
                actual = self.parse(path)
                self.assertEqual(actual.returncode, 1, actual.stderr)
                self.assertEqual(actual.stdout, "")
                self.assertIn("Compilation halted", actual.stderr)
                self.assertIn("at or near", actual.stderr)
                self.assertEqual(self.parse(path, REFERENCE).returncode, 1)

    def test_syntax_is_separate_from_semantics(self):
        self.assert_valid(PROJECT / "tests/syntax-only.cl")

    def test_error_recovery(self):
        # O erro final '#' é uma sentinela: parar no primeiro erro falha aqui.
        cases = [("class", [1, 3]), ("feature", [2, 4]),
                 ("let", [3, 3, 4]), ("block", [3, 5]),
                 ("block-semicolon", [3, 5, 7])]
        for name, expected_lines in cases:
            with self.subTest(recovery=name):
                actual = self.parse(PROJECT / f"tests/recovery-{name}.cl")
                self.assertEqual(actual.returncode, 1, actual.stderr)
                self.assertEqual(actual.stdout, "")
                lines = [int(n) for n in re.findall(r", line (\d+):", actual.stderr)]
                self.assertEqual(lines, expected_lines, actual.stderr)
                self.assertIn('ERROR = #', actual.stderr)

        # Limitação documentada, também observada na referência: yyerrok
        # só ocorre após a cauda/corpo, e erros adjacentes podem ser omitidos.
        adjacent = self.parse(PROJECT / "tests/recovery-let-adjacent.cl")
        self.assertEqual(adjacent.returncode, 1)
        self.assertEqual(adjacent.stdout, "")
        self.assertEqual(re.findall(r", line (\d+):", adjacent.stderr), ["3"])
        self.assertIn("TYPEID = Int", adjacent.stderr)

    def test_error_limit(self):
        actual = self.parse(self.source("class A {\n" + "x : Int <- ;\n" * 60 + "};"))
        self.assertEqual(actual.returncode, 1)
        # Exceção de stdout herdada da rotina oficial, mantida sem alteração.
        self.assertEqual(actual.stdout, "More than 50 errors\n")
        self.assertEqual(len(re.findall(r"at or near", actual.stderr)), 51)

    def test_comprehensive_bad_file(self):
        path = PROJECT / "bad.cl"
        expected = [n for n, line in enumerate(path.read_text().splitlines(), 1)
                    if "-- ERRO:" in line]
        actual = self.parse(path)
        self.assertEqual(actual.returncode, 1)
        self.assertEqual(actual.stdout, "")
        self.assertEqual([int(n) for n in re.findall(r", line (\d+):", actual.stderr)],
                         expected, actual.stderr)

    def test_operator_combinations(self):
        operators = ("+", "-", "*", "/", "<", "<=", "=")
        expressions = [f"a {first} b {second} c"
                       for first in operators for second in operators]
        expressions += [f"{prefix} a {op} b"
                        for prefix in ("not", "isvoid", "~", "not isvoid")
                        for op in operators]
        for expression in expressions:
            with self.subTest(expression=expression):
                path = self.source(f"class Main {{ main():Object {{ {expression} }}; }};")
                actual, expected = self.parse(path), self.parse(path, REFERENCE)
                self.assertEqual(actual.returncode, expected.returncode, actual.stderr)
                if expected.returncode == 0:
                    self.assertEqual(actual.stderr, "")
                    self.assertEqual(normalized(actual.stdout), normalized(expected.stdout))
                else:
                    self.assertEqual(actual.stdout, "")

    def test_node_locations(self):
        path = self.source("class Main {\n x : Int;\n main():Object {\n  1 +\n  2 * 3\n };\n};\n")
        ast = self.assert_valid(path).splitlines()
        locations = [(ast[i + 1].strip(), int(line.strip()[1:]))
                     for i, line in enumerate(ast[:-1])
                     if re.fullmatch(r"\s*#\d+", line)]
        self.assertEqual(locations, [("_program", 1), ("_class", 1),
                                     ("_attr", 2), ("_no_expr", 2),
                                     ("_method", 3), ("_plus", 4),
                                     ("_int", 4), ("_mul", 5),
                                     ("_int", 5), ("_int", 5)])

    def test_official_examples(self):
        examples = sorted((COOL / "examples").glob("*.cl"))
        self.assertGreaterEqual(len(examples), 18)
        for path in examples:
            with self.subTest(example=path.name):
                self.assert_valid(path)

    def test_myparser_script(self):
        result = run([PROJECT / "myparser", "good.cl"])
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stderr, "")
        self.assertIn("_program", result.stdout)

    def test_runtime(self):
        cases = [("good.cl", (PROJECT / "tests/good.expected").read_text()),
                 ("tests/factorial.cl", "120\n"),
                 ("tests/let-scope.cl", "17\n5\n11\n"),
                 ("tests/dispatch.cl", "20\n10\nB\n")]
        for filename, expected in cases:
            with self.subTest(program=filename):
                semant = run([PROJECT / "semant"], input=self.assert_valid(PROJECT / filename))
                self.assertEqual(semant.returncode, 0, semant.stderr)
                self.assertEqual(semant.stderr, "")
                assembly = self.work / "program.s"
                cgen = run([PROJECT / "cgen", "-o", assembly], input=semant.stdout)
                self.assertEqual(cgen.returncode, 0, cgen.stderr)
                self.assertEqual(cgen.stderr, "")
                executed = run([COOL / "bin/spim", "-file", assembly], input="")
                self.assertEqual(executed.returncode, 0, executed.stderr)
                self.assertEqual(executed.stderr, "")
                self.assertIn("COOL program successfully executed", executed.stdout)
                body = executed.stdout.split("Loaded:", 1)[1].split("\n", 1)[1]
                body = body.split("COOL program successfully executed", 1)[0]
                self.assertEqual(body, expected)


if __name__ == "__main__":
    unittest.main(verbosity=2)

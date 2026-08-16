class StackCommand {
  next : StackCommand;

  set_next(command : StackCommand) : StackCommand {
    {
      next <- command;
      self;
    }
  };

  get_next() : StackCommand { next };

  print() : Object { self };

  display() : Object {
    {
      print();
      if isvoid next then self else next.display() fi;
    }
  };
};

class IntCommand inherits StackCommand {
  value : Int;

  init(number : Int) : IntCommand {
    {
      value <- number;
      self;
    }
  };

  get_value() : Int { value };

  print() : Object { (new IO).out_int(value).out_string("\n") };
};

class PlusCommand inherits StackCommand {
  print() : Object { (new IO).out_string("+\n") };
};

class SwapCommand inherits StackCommand {
  print() : Object { (new IO).out_string("s\n") };
};

class StackMachine {
  top : StackCommand;

  push(command : StackCommand) : Object {
    {
      command.set_next(top);
      top <- command;
      self;
    }
  };

  display() : Object {
    if isvoid top then self else top.display() fi
  };

  evaluate() : Object {
    if isvoid top then self else
      case top of
        plus : PlusCommand => {
          top <- plus.get_next();
          case top of
            first : IntCommand => {
              top <- first.get_next();
              case top of
                second : IntCommand => {
                  top <- second.get_next();
                  push((new IntCommand).init(
                    first.get_value() + second.get_value()
                  ));
                };
                command : StackCommand => self;
              esac;
            };
            command : StackCommand => self;
          esac;
        };
        swap : SwapCommand => {
          top <- swap.get_next();
          let first : StackCommand <- top,
              second : StackCommand <- first.get_next(),
              rest : StackCommand <- second.get_next()
          in {
            second.set_next(first);
            first.set_next(rest);
            top <- second;
          };
        };
        command : StackCommand => self;
      esac
    fi
  };
};

class Main inherits A2I {
  machine : StackMachine <- new StackMachine;
  io : IO <- new IO;

  main() : Object {
    let running : Bool <- true,
        command : String
    in {
      while running loop {
        io.out_string(">");
        command <- io.in_string();
        if command = "x" then
          running <- false
        else if command = "d" then
          machine.display()
        else if command = "e" then
          machine.evaluate()
        else if command = "+" then
          machine.push(new PlusCommand)
        else if command = "s" then
          machine.push(new SwapCommand)
        else
          machine.push((new IntCommand).init(a2i(command)))
        fi fi fi fi fi;
      } pool;
      0;
    }
  };
};

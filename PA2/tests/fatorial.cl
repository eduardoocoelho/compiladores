class Main inherits IO {
    fat(n : Int) : Int {
        if n <= 1 then
            1
        else
            n * fat(n - 1)
        fi
    };

    main() : Object {
        let resultado : Int <- fat(5) in
            out_string("Fatorial de 5 calculado com sucesso!\n")
    };
};

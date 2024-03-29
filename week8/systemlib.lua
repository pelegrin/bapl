local systemlib = {}

systemlib._version = "System library v.0.8"


systemlib.vm = {
          substring = {
                params = 2,
                ["type"] = "func",
                rettype = "string",
                code = {"load", -1, "size", "push", 0, "eq", "jmpnzp", 6, "load", -2, "push", 0, "eq", "noop", "jmpnzp", 7, "load", -2, "load", -1, "size", "gt", "noop", "jmpnzp", 8, "load", -2, "minus", "load", -1, "size", "gt", "noop", "jmpz", 4, "load", -1, "ret", "noop", "init", 2, "number", "init", 3, "number", "load", -2, "push", 0, "gt", "jmpz", 10, "load", -2, "store", 2, "push", 1, "store", 3, "jmp", 17, "load", -1, "size", "load", -2, "add", "push", 1, "add", "store", 3, "load", -2, "minus", "store", 2, "noop", "init", 4, "string", "push", "", "store", 4, "load", 2, "push", 0, "gt", "jmpz", 26, "load", 4, "load", 3, "loadat", -1, "add", "store", 4, "load", 3, "push", 1, "add", "store", 3, "load", 2, "push", 1, "sub", "store", 2, "jmp", -32, "noop", "load", 4, "ret", "noop"}
          }
}
systemlib.interpreter = {
          substring =  {
                  params = 2,
                  ["type"] = "func",
                  scope = "system",
                  rettype = "string",
                  val = "substring"
          }
}

return systemlib
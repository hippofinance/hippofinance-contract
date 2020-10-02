import os
import json

for file in os.scandir("./build/contracts"):
    json.dump(
        json.load(open(file.path, "r"))['abi'],
        open("./abi/" + file.name, "w"),
        indent=4
    )



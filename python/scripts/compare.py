def parse_data(data: str):
    # Strip curly braces and split by commas at top level
    data = data.strip().strip("{}")
    items = data.split(", ")
    parsed = {}
    for item in items:
        if "=" in item:
            city, vals = item.split("=", 1)
            parsed[city.strip()] = vals.strip()
    return parsed


def compare(dict1, dict2):
    diffs = {}
    for city in dict1:
        if city not in dict2:
            diffs[city] = ("MISSING in second", dict1[city], None)
        elif dict1[city] != dict2[city]:
            diffs[city] = (dict1[city], dict2[city])
    for city in dict2:
        if city not in dict1:
            diffs[city] = ("MISSING in first", None, dict2[city])
    return diffs


if __name__ == "__main__":
    with (
        open("../data/answers.txt") as f1,
        open("../data/python-output-latest.txt") as f2,
    ):
        dict1 = parse_data(f1.read())
        dict2 = parse_data(f2.read())

    differences = compare(dict1, dict2)
    print(f"\nFound {len(differences)} differences:\n")
    for city, vals in differences.items():
        if len(vals) == 2:
            print(f"{city}: {vals[0]}  →  {vals[1]}")
        else:
            print(f"{city}: {vals}")

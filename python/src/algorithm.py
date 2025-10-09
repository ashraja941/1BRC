from collections import defaultdict
import time
from tqdm import tqdm


def processData(path: str):
    stationDict: defaultdict[str, list[float]] = defaultdict(
        lambda: [float("inf"), float("-inf"), 0, 0]
    )

    with open(path, "r") as f:
        for line in tqdm(f):
            try:
                stationName, temperature = line.strip().split(";")
            except ValueError:
                print("ValueError")
                continue
            temperature = int(10 * float(temperature))

            stats = stationDict[stationName]
            stats[0] = min(stats[0], temperature)
            stats[1] = max(stats[1], temperature)
            stats[2] += temperature
            stats[3] += 1

    return stationDict


def createOutput(stationDict: defaultdict[str, list[float]]):
    output: list[str] = []
    for stationName in sorted(stationDict.keys()):
        minVal, maxVal, total, count = stationDict[stationName]
        minVal /= 10.0
        maxVal /= 10.0
        # meanVal = ceilDiv(total, count) / 10.0
        meanVal = (total / count) / 10.0
        output.append(f"{stationName}={minVal:.1f}/{meanVal:.1f}/{maxVal:.1f}")

    return "{" + ", ".join(output) + "}"


def write_output(output: str, out_path: str):
    with open(out_path, "w", encoding="utf-8") as f:
        _ = f.write(output)
        _ = f.write("\n")


if __name__ == "__main__":
    answer = "../data/answers.txt"
    tenMilPath = "../data/10mil.txt"
    oneBil = "../data/measurements.txt"
    chosenPath = oneBil

    results: float = 0.0
    print("starting...")

    startTime: float = time.time()
    processedData = processData(chosenPath)
    output = createOutput(processedData)

    write_output(output, "../data/python-output-latest.txt")

    endTime: float = time.time()
    results = endTime - startTime

    print(f"completed run : {results} seconds")

    with open(answer, "r") as f:
        answerOutput = f.read().strip()
        if output == answerOutput:
            print("Output matches answer")
        else:
            print("Output does not match answer")

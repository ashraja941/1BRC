import os
import multiprocessing as mp

from collections import defaultdict
import time
from typing import ByteString
from tqdm import tqdm


def getFileChunks(
    filePath: str, maxCPU: int = 8
) -> tuple[int, list[tuple[str, int, int]]]:
    """
    Splits a file into chunks for parallel processing.

    Args:
        filePath (str): The path to the file to be split.
        maxCPU (int): The maximum number of CPU cores to use.

    Returns:
        tuple[int, list[tuple[str, int, int]]]: A tuple containing the number of chunks and a list of tuples representing the start and end positions of each chunk.
    """
    cpuCount = min(maxCPU, mp.cpu_count())
    fileSize = os.path.getsize(filePath)
    chunkSize = fileSize // cpuCount

    startEnd: list[tuple[str, int, int]] = list()
    with open(filePath, "r+b") as f:

        def isNewLine(position: int) -> bool:
            if position == 0:
                return True
            else:
                _ = f.seek(position - 1)
                return f.read(1) == b"\n"

        def nextLine(position: int):
            _ = f.seek(position)
            _ = f.readline()
            return f.tell()

        chunkStart = 0
        while chunkStart < fileSize:
            chunkEnd = min(chunkStart + chunkSize, fileSize)
            while not isNewLine(chunkEnd):
                chunkEnd -= 1

            if chunkStart == chunkEnd:
                chunkEnd = nextLine(chunkEnd)

            startEnd.append((filePath, chunkStart, chunkEnd))
            chunkStart = chunkEnd
    return (cpuCount, startEnd)


def initDefaultDict():
    return [float("inf"), float("-inf"), 0, 0]


def processChunk(path: str, start: int, end: int):
    stationDict: defaultdict[ByteString, list[float]] = defaultdict(initDefaultDict)

    with open(path, "r+b") as f:
        _ = f.seek(start)
        for line in tqdm(f):
            start += len(line)
            if start > end:
                break

            try:
                stationName, temperature = line.strip().split(b";")
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


def mergeChunkResults(cpuCount: int, startEnd: list[tuple[str, int, int]]):
    with mp.Pool(cpuCount) as pool:
        chunkResults = pool.starmap(processChunk, startEnd)

    results: dict[str, list[float]] = dict()
    for chunkResult in chunkResults:
        for stationName, stats in chunkResult.items():
            stationName = stationName.decode("utf-8")
            if stationName not in results:
                results[stationName] = stats
                continue

            results[stationName][0] = min(results[stationName][0], stats[0])
            results[stationName][1] = max(results[stationName][1], stats[1])
            results[stationName][2] += stats[2]
            results[stationName][3] += stats[3]

    return results


def createOutput(stationDict: dict[str, list[float]]):
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


def runMutltiProcessing(chosenPath: str):
    cpuCount, startEnd = getFileChunks(chosenPath)
    processedData = mergeChunkResults(cpuCount, startEnd)
    output = createOutput(processedData)
    return output


if __name__ == "__main__":
    answer = "../data/answers.txt"
    tenMilPath = "../data/10mil.txt"
    oneBil = "../data/measurements.txt"
    chosenPath = oneBil

    results: float = 0.0
    print("starting...")

    startTime: float = time.time()
    output = runMutltiProcessing(chosenPath)
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

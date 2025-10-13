from src.algorithm import processData, createOutput
from src.polarsImplementation import run

import time

if __name__ == "__main__":
    tenMilPath = "../data/10mil.txt"
    oneBil = "../data/measurements.txt"
    chosenPath = oneBil

    results: list[float] = [0.0] * 5
    print("starting...")

    for i in range(5):
        startTime: float = time.time()
        # processedData = processData(chosenPath)
        # output = createOutput(processedData)

        output = run(chosenPath)

        endTime: float = time.time()
        results[i] = endTime - startTime
        print(f"completed run {i + 1} : {results[i]}")

    results.sort()
    finalTime = sum(results[:3]) / 3.0
    print("Final Time : ", finalTime)

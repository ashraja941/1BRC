import time
from tokenize import group
import polars as pl


def write_output(output: str, out_path: str):
    with open(out_path, "w", encoding="utf-8") as f:
        _ = f.write(output)
        _ = f.write("\n")


def run(inputDataPath: str):
    df = pl.scan_csv(
        source=inputDataPath,
        separator=";",
        has_header=False,
        with_column_names=lambda cols: ["stationName", "measurement"],
    )

    grouped = (
        df.group_by("stationName")
        .agg(
            pl.min("measurement").alias("min"),
            pl.mean("measurement").alias("mean"),
            pl.max("measurement").alias("max"),
        )
        .sort("stationName")
        .collect(engine="streaming")
    )

    outputList = []

    for data in grouped.iter_rows():
        outputList.append(f"{data[0]}={data[1]:.1f}/{data[2]:.1f}/{data[3]:.1f}")

    output: str = "{" + ", ".join(outputList) + "}"
    return output


if __name__ == "__main__":
    answer = "../data/answers.txt"
    tenMilPath = "../data/10mil.txt"
    oneBil = "../data/measurements.txt"
    chosenPath = oneBil

    results: float = 0.0
    print("starting...")

    startTime: float = time.time()

    output = run(chosenPath)

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

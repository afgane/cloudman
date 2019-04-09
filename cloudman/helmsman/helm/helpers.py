import csv
import io
import subprocess


def run_command(command, shell=False):
    """
    Runs a command and returns stdout
    """
    return subprocess.check_output(command, universal_newlines=True,
                                   shell=shell)


def run_list_command(command):
    """
    Runs a command, and parses the output as
    tab separated columnar output. First row must be column names."
    """
    output = run_command(command)
    reader = csv.DictReader(io.StringIO(output), delimiter="\t")
    output = []
    for row in reader:
        data = {key.strip(): val.strip() for key, val in row.items()}
        output.append(data)
    return output


# based on: https://codereview.stackexchange.com/questions/21033/flatten-dic
# tionary-in-python-functional-style
def flatten_dict(d):
    def items():
        for key, value in d.items():
            if isinstance(value, dict):
                for subkey, subvalue in flatten_dict(value).items():
                    yield key + "." + subkey, subvalue
            else:
                yield key, value
    return dict(items())

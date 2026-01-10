import subprocess
import os

from . import manifest

class Chart:
    """
    A Chart object represents a helm chart that can be used to generate
    kubernetes manifests.
    """

    def __init__(self, chart_dir, binary = None):
        self.chart_dir = chart_dir

        self.binary = binary or os.environ.get('HELM_BIN', "helm")

    def render(self, name = "dummy", value_files = None, options = None):
        """
        Calls helm to render the chart's templates into a series of kubernetes manifests.
        options are passed directly to helm. If an option value is False or None, the option
        is omitted. If the value is True, it will be passed as a flag with no value.
        """

        cmd = [
            self.binary,
            "template",
            name,
            "."
        ]

        for f in value_files or []:
            cmd.append("-f")
            cmd.append(f)

        if options:
            for opt, val in options.items():
                cmd.append(opt)

                if val is False or val is None:
                    continue

                if val is not True:
                    cmd.append(val)

        result = subprocess.run(
            cmd,
            text = True,
            capture_output = True,
            cwd=self.chart_dir,
            check = True,
            timeout = 20
        )

        yaml = result.stdout

        manifests = manifest.ManifestSet()
        manifests.load_yaml_data( yaml )

        return manifests

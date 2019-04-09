import logging as log
import os

from django.apps import AppConfig
from django.core.management import call_command


class HelmsmanConfig(AppConfig):
    name = 'helmsman'

    def ready(self):
        try:
            if os.environ.get("HELMSMAN_AUTO_DEPLOY"):
                call_command("load_helmsman_config",
                             "/opt/cloudman/helmsman_config.yaml")
        except Exception as e:
            log.exception(
                "An error occurred while loading helmsman_config.yaml: ")
            print("An error occurred while loading helmsman_config.yaml: ", e)

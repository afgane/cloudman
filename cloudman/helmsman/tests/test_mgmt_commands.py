import os

from django.contrib.auth.models import User
from django.core.management import call_command
from django.core.management.base import CommandError
from django.test import TestCase

from .mock_helm import MockHelm
from ..helm.client import HelmClient


class CommandsTestCase(TestCase):

    TEST_DATA_PATH = os.path.join(os.path.dirname(__file__), 'data')
    INITIAL_HELMSMAN_DATA = os.path.join(
        TEST_DATA_PATH, 'helmsman_config.yaml')

    def setUp(self):
        super().setUp()
        self.mock_helm = MockHelm(self)
        self.client.force_login(
            User.objects.get_or_create(username='admin', is_superuser=True)[0])

    def tearDown(self):
        self.client.logout()

    def test_helmsman_load_config_no_args(self):
        with self.assertRaisesRegex(CommandError, "required: config_file"):
            call_command('helmsman_load_config')

    def test_helmsman_load_config(self):
        call_command('helmsman_load_config', self.INITIAL_HELMSMAN_DATA)
        client = HelmClient()
        repos = client.repositories.list()
        for repo in repos:
            self.assertIn(repo.get('NAME'), ["stable", "cloudve", "jupyterhub"])
        releases = client.releases.list()
        for rel in releases:
            self.assertIn(rel.get('CHART'),
                          ["cloudlaunch-0.2.0", "galaxy-cvmfs-csi-1.0.0",
                           "kubernetes-dashboard-1.0.0", "galaxy-1.0.0"])
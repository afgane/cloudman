from django.contrib.auth.models import User
from django.urls import reverse
from rest_framework import status
from rest_framework.test import APITestCase

from .mock_helm import MockHelm


# Create your tests here.
class HelmsManServiceTestBase(APITestCase):

    def setUp(self):
        self.mock_helm = MockHelm(self)
        self.client.force_login(
            User.objects.get_or_create(username='admin')[0])

    def tearDown(self):
        self.client.logout()


class RepoServiceTests(HelmsManServiceTestBase):

    def test_crud_repo(self):
        """
        Ensure we can register a new cluster with cloudman.
        """
        # Check listing
        url = reverse('repositories-list')
        response = self.client.get(url)
        self.assertEqual(response.status_code, status.HTTP_200_OK)


class ChartServiceTests(HelmsManServiceTestBase):

    CHART_DATA = {
        'name': 'galaxy',
        'display_name': 'Galaxy',
        'chart_version': '3.0.0',
        'namespace': 'gvl',
        'state': "DEPLOYED",
        'values': {
            'hello': 'world'
        }
    }

    def test_crud_chart(self):
        """
        Ensure we can register a new cluster with cloudman.
        """
        # create the object
        url = reverse('charts-list')
        response = self.client.post(url, self.CHART_DATA, format='json')
        self.assertEqual(response.status_code, status.HTTP_201_CREATED, response.data)

        # list existing objects
        url = reverse('charts-list')
        response = self.client.get(url)
        self.assertEqual(response.status_code, status.HTTP_200_OK, response.data)
        self.assertDictContainsSubset(self.CHART_DATA, response.data['results'][1])

        # check it exists
        url = reverse('charts-detail', args=[response.data['results'][1]['id']])
        response = self.client.get(url)
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertDictContainsSubset(self.CHART_DATA, response.data)

        # # delete the object
        # url = reverse('charts-detail', args=[response.data['id']])
        # response = self.client.delete(url)
        # self.assertEqual(response.status_code, status.HTTP_204_NO_CONTENT)
        #
        # # check it no longer exists
        # url = reverse('clusters-list')
        # response = self.client.get(url)
        # self.assertEqual(response.status_code, status.HTTP_200_OK)

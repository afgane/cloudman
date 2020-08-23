import abc
from rest_framework.exceptions import ValidationError
from .clients.rancher import RancherClient
from cloudlaunch import models as cl_models


class CMClusterTemplate(object):

    def __init__(self, context, cluster):
        self.context = context
        self.cluster = cluster

    @property
    def connection_settings(self):
        return self.cluster.connection_settings

    @abc.abstractmethod
    def add_node(self, name, size):
        pass

    @abc.abstractmethod
    def remove_node(self):
        pass

    @abc.abstractmethod
    def activate_autoscaling(self, min_nodes=0, max_nodes=None, size=None):
        pass

    @abc.abstractmethod
    def deactivate_autoscaling(self):
        pass

    @staticmethod
    def get_template_for(context, cluster):
        if cluster.cluster_type == "KUBE_RANCHER":
            return CMRancherTemplate(context, cluster)
        else:
            raise KeyError("Cannon get cluster template for unknown cluster "
                           "type: %s" % cluster.cluster_type)


class CMRancherTemplate(CMClusterTemplate):

    def __init__(self, context, cluster):
        super(CMRancherTemplate, self).__init__(context, cluster)
        settings = cluster.connection_settings.get('rancher_config')
        self._rancher_url = settings.get('rancher_url')
        self._rancher_api_key = settings.get('rancher_api_key')
        self._rancher_cluster_id = settings.get('rancher_cluster_id')
        self._rancher_project_id = settings.get('rancher_project_id')

    @property
    def rancher_url(self):
        return self._rancher_url

    @property
    def rancher_api_key(self):
        return self._rancher_api_key

    @property
    def rancher_cluster_id(self):
        return self._rancher_cluster_id

    @property
    def rancher_project_id(self):
        return self._rancher_project_id

    @property
    def rancher_client(self):
        return RancherClient(self.rancher_url, self.rancher_api_key,
                             self.rancher_cluster_id,
                             self.rancher_project_id)

    def _find_matching_vm_type(self, zone_model=None, default_vm_type=None,
                               min_vcpus=0, min_ram=0, vm_family=""):
        """
        Finds the vm_type that best matches the given criteria. If no criteria
        is specified, will return the default vm type.

        :param zone_model:
        :param default_vm_type:
        :param min_vcpus:
        :param min_ram:
        :param vm_family:
        :return:
        """
        vm_type = default_vm_type or self.cluster.default_vm_type
        if min_vcpus > 0 or min_ram > 0 or not vm_type.startswith(vm_family):
            cloud = self.context.cloudlaunch_client.infrastructure.clouds.get(
                zone_model.region.cloud.id)
            region = cloud.regions.get(zone_model.region.region_id)
            zone = region.zones.get(zone_model.zone_id)
            default_matches = zone.vm_types.list(vm_type_prefix=vm_type)
            if default_matches:
                default_match = default_matches[0]
                min_vcpus = min_vcpus if min_vcpus > int(default_match.vcpus) else default_match.vcpus
                min_ram = min_ram if min_ram > float(default_match.ram) else default_match.ram
            candidates = zone.vm_types.list(min_vcpus=min_vcpus, min_ram=min_ram,
                                            vm_type_prefix=vm_family)
            if candidates:
                candidate_type = sorted(candidates, key=lambda x: int(x.vcpus) * float(x.ram))[0]
                return candidate_type.name
        return vm_type

    def add_node(self, name, vm_type=None, zone=None, min_vcpus=0, min_ram=0, vm_family=""):
        settings = self.cluster.connection_settings
        zone = zone or self.cluster.default_zone
        deployment_target = cl_models.CloudDeploymentTarget.objects.get(
            target_zone=zone)
        params = {
            'name': name,
            'application': 'cm_rancher_kubernetes_plugin',
            'deployment_target_id': deployment_target.id,
            'application_version': '0.1.0',
            'config_app': {
                'rancher_action': 'add_node',
                'config_rancher_kube': {
                    'rancher_url': self.rancher_url,
                    'rancher_api_key': self.rancher_api_key,
                    'rancher_cluster_id': self.rancher_cluster_id,
                    'rancher_project_id': self.rancher_project_id,
                    'rancher_node_command': (
                        self.rancher_client.get_cluster_registration_command()
                        + " --worker")
                },
                "config_appliance": {
                    "sshUser": "ubuntu",
                    "runner": "ansible",
                    "repository": "https://github.com/CloudVE/ansible-docker-boot",
                    "inventoryTemplate": "${host}\n\n"
                                         "[all:vars]\n"
                                         "ansible_ssh_port=22\n"
                                         "ansible_user='${user}'\n"
                                         "ansible_ssh_private_key_file=pk\n"
                                         "ansible_ssh_extra_args='-o StrictHostKeyChecking=no'\n"
                },
                'config_cloudlaunch': (settings.get('app_config', {})
                                       .get('config_cloudlaunch', {})),
                'config_cloudman': {
                    'cluster_name': self.cluster.name
                }
            }
        }

        params['config_app']['config_cloudlaunch']['vmType'] = \
            self._find_matching_vm_type(
                zone_model=zone, default_vm_type=vm_type, min_vcpus=min_vcpus,
                min_ram=min_ram, vm_family=vm_family)

        print("Adding node: {0} of type: {1}".format(
            name, params['config_app']['config_cloudlaunch']['vmType']))

        # Don't use hostname config
        params['config_app']['config_cloudlaunch'].pop('hostnameConfig', None)
        try:
            print("Launching node with settings: {0}".format(params))
            return self.context.cloudlaunch_client.deployments.create(**params)
        except Exception as e:
            raise ValidationError("Could not launch node: " + str(e))

    def remove_node(self, node):
        return self.context.cloudlaunch_client.deployments.tasks.create(
            action='DELETE', deployment_pk=node.deployment.pk)


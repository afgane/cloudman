"""
The base services package; all CloudMan services derive from this class.
"""
import datetime as dt
from cm.util.bunch import Bunch

import logging
log = logging.getLogger( 'cloudman' )

service_states = Bunch(
    UNSTARTED="Unstarted",
    WAITING_FOR_USER_ACTION="Waiting for user action",
    CONFIGURING="Configuring",
    STARTING="Starting",
    RUNNING = "Running",
    SHUTTING_DOWN = "Shutting down",
    SHUT_DOWN="Shut down",
    ERROR="Error"
 )


class ServiceType(object):
    FILE_SYSTEM = "FileSystem"
    APPLICATION = "Application"
  

class ServiceRole(object):    
    SGE = {'type': ServiceType.APPLICATION, 'name': "Sun Grid Engine"}
    GALAXY = {'type': ServiceType.APPLICATION, 'name': "Galaxy"}
    GALAXY_POSTGRES = {'type': ServiceType.APPLICATION, 'name': "Postgres DB for Galaxy"}
    GALAXY_REPORTS = {'type': ServiceType.APPLICATION, 'name': "Galaxy Reports"}
    AUTOSCALE = {'type': ServiceType.APPLICATION, 'name': "Autoscale"}
    PSS = {'type': ServiceType.APPLICATION, 'name': "Post Start Script"}
    GALAXY_DATA  = {'type': ServiceType.FILE_SYSTEM, 'name': "Galaxy Data FS"}
    GALAXY_INDICES  = {'type': ServiceType.FILE_SYSTEM, 'name': "Galaxy Indices FS"}
    GALAXY_TOOLS = {'type': ServiceType.FILE_SYSTEM, 'name': "Galaxy Tools FS"}
    GENERIC_FS = {'type': ServiceType.FILE_SYSTEM, 'name': "Generic FS"}
    TRANSIENT_NFS = {'type': ServiceType.FILE_SYSTEM, 'name': "Transient NFS FS"}

class ServiceDependency(object):
    """
    Represents a dependency that another service required for its function.
    A service dependency may have the following attributes:
    owning_service - The parent service whose dependency this instance describes.
    service_role - The specific role that this instance of the service is playing. For example, there may be
                   multiple File System services providing/fulfilling different requirements
    assigned_service - Represents the service currently assigned to fulfill this dependency.  
    """
    def __init__( self, owning_service, service_role, assigned_service=None ):
        self._owning_service = owning_service
        self._service_role = service_role
        self._assigned_service = assigned_service
 
    @property
    def owning_service(self):
        return self._owning_service
      
    @property  
    def service_type(self):
        return self._service_role['type']
    
    @property
    def service_role(self):
        return self._service_role
 
    @property
    def assigned_service(self):
        return self._assigned_service   

    @assigned_service.setter
    def assigned_service(self, value):
        self._assigned_service = value
        
    def satisfies(self, service):
        """
        Determines whether this service dependency satisfies a given service
        """
        if (service.svc_role == self.service_role()):
            return True
        else:
            return False
        
    def remove(self):
        """
        Calls the remove method on the currently assigned service
        and sets the currently assigned service to Null
        """
        if (self.assigned_service() is not None):
            log.debug("Removing service and dependency named {0} with role {1} belonging to service (3)."\
                      .format(self.assigned_service(), self.service_role()['name'], self.owning_service()))
            self.assigned_service().remove()
            self.assigned_service(None)


class Service( object):

    def __init__( self, app, service_type=None ):
        self.app = app
        self.state = service_states.UNSTARTED
        self.last_state_change_time = dt.datetime.utcnow()
        self.svc_role = None
        self.reqs = []

    def add (self):
        """
        Add a given service to the pool of services managed by CloudMan, giving
        CloudMan the abilty to monitor and control the service. This is a base
        implementation of the service ``add`` method which calls service's internal
        ``start`` method. Before calling the ``start`` method, service prerequisites
        are checked and, if satisfied, the service is started. If the prerequisites
        are not satisfied, the service is set to state ``UNSTARTED``.
        """
        if self.state != service_states.RUNNING:
            # log.debug("Trying to add service '%s'" % self.svc_role)
            self.state = service_states.STARTING
            self.last_state_change_time = dt.datetime.utcnow()
            failed_prereqs = [] # List of service prerequisites that have not been satisfied
            for service in self.reqs:
                # log.debug("'%s' service checking its prerequisite '%s:%s'" \
                #    % (self.get_full_name(), svc_role, name))
                for svc in self.app.manager.services:
                    # log.debug("Checking service %s state." % svc.svc_role)
                    if svc.svc_role==service.service_role:
                    # log.debug("Service %s:%s running: %s" % (svc.svc_role, svc.name, svc.running()))
                        if not svc.running():
                            failed_prereqs.append(svc.get_full_name())
                    else:
                        # log.debug("Service %s running: %s" % (svc.svc_role, svc.running()))
                        if not svc.running():
                            failed_prereqs.append(svc.get_full_name())
            if len(failed_prereqs) == 0:
                log.info("{0} service prerequisites OK; starting the service".format(self.get_full_name()))
                self.start()
                return True
            else:
                log.debug("{0} service prerequisites are not yet satisfied, missing: {2}. "\
                        "Setting {0} service state to '{1}'"\
                        .format(self.get_full_name(), service_states.UNSTARTED, failed_prereqs))
                # Reset state so it get picked back up by monitor
                self.state = service_states.UNSTARTED
                return False

    def remove(self):
        """
        Recursively removes a service and all services that depend on it.
        Child classes which override this method should ensure this is called
        for proper removal of service dependencies.
        """
        print "Removing service: " % self.name
        for service in self.app.manager.services:
            for dependent_svc in service.reqs:
                if (dependent_svc.satisfies(self)):
                    print "Removing dependent service: " % dependent_svc.service_name % " of service: " % self.name
                    dependent_svc.remove()

    def running(self):
        """
        Return ``True`` is service is in state ``RUNNING``, ``False`` otherwise
        """
        return self.state == service_states.RUNNING

    def get_full_name(self):
        """
        Return full name of the service (useful if different from service type)
        """
        return self.svc_role

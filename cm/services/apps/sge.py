import shutil, tarfile, os, time, subprocess, pwd, grp, datetime, commands

from cm.services.apps import ApplicationService
from cm.util import paths, templates
from cm.services import service_states
from cm.util import misc

import logging
log = logging.getLogger( 'cloudman' )


class SGEService( ApplicationService ):
    def __init__(self, app):
        super(SGEService, self).__init__(app)
        self.svc_type = "SGE"
        self.hosts = []
    
    def start(self):
        if self.unpack_sge():
            self.configure_sge()
        else:
            log.error("Error adding service '%s'" % self.svc_type)
            self.state = service_states.ERROR
    
    def remove(self):
        # TODO write something to clean up SGE in the case of restarts?
        log.info("Removing SGE service")
        self.state = service_states.SHUTTING_DOWN
        for inst in self.app.manager.worker_instances:
            self.remove_sge_host(inst)
        
        misc.run('export SGE_ROOT=%s; . $SGE_ROOT/default/common/settings.sh; %s/bin/lx24-amd64/qconf -km' % (paths.P_SGE_ROOT, paths.P_SGE_ROOT), "Problems stopping SGE master", "Successfully stopped SGE master")
        self.state = service_states.SHUT_DOWN
    
    def clean(self):
        """ Stop SGE and clean up the system as if SGE was never installed. Useful for CloudMan restarts."""
        self.remove()
        if self.state == service_states.SHUT_DOWN:
            misc.run('rm -rf %s/*' % paths.SGE_ROOT, "Error cleaning SGE_ROOT (%s)" % paths.SGE_ROOT, "Successfully cleaned SGE_ROOT")
            with open('/etc/bash.bashrc', 'r') as f:
                lines = f.readlines()
            d1 = d2 = -1
            for i, l in enumerate(lines):
                if "export SGE_ROOT=%s" % paths.P_SGE_ROOT in l:
                    d1 = i
                if ". $SGE_ROOT/default/common/settings.sh" in l:
                    d2 = i
            if d1 != -1:
                del lines[d1]
            if d2 != -1:
                del lines[d2]
            if d1!=-1 or d2!=-1:
                with open('/etc/bash.bashrc', 'w') as f:
                    f.writelines(lines)
    
    def unpack_sge( self ):
        if self.app.TESTFLAG is True:
            log.debug( "Attempted to get volumes, but TESTFLAG is set." )
            return False
        log.debug("Unpacking SGE from '%s'" % paths.P_SGE_TARS)
        os.putenv( 'SGE_ROOT', paths.P_SGE_ROOT )
        # Ensure needed directory exists
        if not os.path.exists( paths.P_SGE_TARS ):
            log.error( "'%s' directory with SGE binaries does not exist! Aborting SGE setup." % paths.P_SGE_TARS )
            return False
        if not os.path.exists( paths.P_SGE_ROOT ):
            os.mkdir ( paths.P_SGE_ROOT )
        # Ensure SGE_ROOT directory is empty (useful for restarts)
        if len(os.listdir(paths.P_SGE_ROOT)) > 0:
            # Check if qmaster is running in that case
            self.status()
            if self.state==service_states.RUNNING:
                log.info("Found SGE already running; will reconfigure it.")
                self.stop_sge()
            log.debug("Cleaning '%s' directory." % paths.P_SGE_ROOT)
            for base, dirs, files in os.walk(paths.P_SGE_ROOT):
                for f in files:
                    os.unlink(os.path.join(base, f))
                for d in dirs:
                    shutil.rmtree(os.path.join(base, d))
        log.debug( "Unpacking SGE to '%s'." % paths.P_SGE_ROOT )
        tar = tarfile.open( '%s/ge-6.2u5-common.tar.gz' % paths.P_SGE_TARS )
        tar.extractall( path=paths.P_SGE_ROOT )
        tar.close()
        tar = tarfile.open( '%s/ge-6.2u5-bin-lx24-amd64.tar.gz' % paths.P_SGE_TARS )
        tar.extractall( path=paths.P_SGE_ROOT )
        tar.close()
        subprocess.call( '%s -R sgeadmin:sgeadmin %s' % (paths.P_CHOWN, paths.P_SGE_ROOT), shell=True )
        return True
    
    def configure_sge( self ):
        if self.app.TESTFLAG is True:
            log.debug( "Attempted to get volumes, but TESTFLAG is set." )
            return None
        log.info( "Configuring SGE..." )
        # Add master as an execution host
        # Additional execution hosts will be added later, as they start
        exec_nodes = self.app.cloud_interface.get_self_private_ip() 
        SGE_config_file = '%s/galaxyEC2.conf' % paths.P_SGE_ROOT
        with open( SGE_config_file, 'w' ) as f:
            print >> f, templates.SGE_INSTALL_TEMPLATE % ( self.app.cloud_interface.get_self_private_ip(), self.app.cloud_interface.get_self_private_ip(), exec_nodes )
        os.chown( SGE_config_file, pwd.getpwnam( "sgeadmin" )[2], grp.getgrnam( "sgeadmin" )[2] )
        log.debug( "Created SGE install template as file '%s'" % SGE_config_file )
        log.info( "Setting up SGE." )
        if misc.run( 'cd %s; ./inst_sge -m -x -auto %s' % (paths.P_SGE_ROOT, SGE_config_file), "Setting up SGE did not go smoothly", "Successfully set up SGE"):
            log.info("Successfully setup SGE; configuring SGE")
            SGE_allq_file = '%s/all.q.conf' % paths.P_SGE_ROOT
            with open( SGE_allq_file, 'w' ) as f:
                print >> f, templates.ALL_Q_TEMPLATE
            os.chown( SGE_allq_file, pwd.getpwnam( "sgeadmin" )[2], grp.getgrnam( "sgeadmin" )[2] )
            log.debug( "Created SGE all.q template as file '%s'" % SGE_allq_file )
            misc.run ( 'cd %s; ./bin/lx24-amd64/qconf -Mq %s' % (paths.P_SGE_ROOT, SGE_allq_file), "Error modifying all.q", "Successfully modified all.q")
            # Prevent 'Unexpected operator' to show up at shell login (SGE bug on Ubuntu)
            misc.replace_string(paths.P_SGE_ROOT + '/util/arch', "         libc_version=`echo $libc_string | tr ' ,' '\\n' | grep \"2\.\" | cut -f 2 -d \".\"`", "         libc_version=`echo $libc_string | tr ' ,' '\\n' | grep \"2\.\" | cut -f 2 -d \".\" | sort -u`")
            misc.run("chmod +rx %s/util/arch" % paths.P_SGE_ROOT, "Error chmod %s/util/arch" % paths.P_SGE_ROOT, "Successfully chmod %s/util/arch" % paths.P_SGE_ROOT)
            log.debug("Configuring users' SGE profiles" )
            with open( "/etc/bash.bashrc", 'a' ) as f:
                f.write( "\nexport SGE_ROOT=%s" % paths.P_SGE_ROOT )
                f.write( "\n. $SGE_ROOT/default/common/settings.sh\n" )
    
    def add_sge_host( self, inst ):
        # TODO: Should check to ensure SGE_ROOT mounted on worker
        proc = subprocess.Popen( "export SGE_ROOT=%s; . $SGE_ROOT/default/common/settings.sh; %s/bin/lx24-amd64/qconf -shgrp @allhosts" % (paths.P_SGE_ROOT, paths.P_SGE_ROOT), shell=True, stdout=subprocess.PIPE )
        allhosts_out = proc.communicate()[0]
        inst_ip = inst.get_private_ip()
        error = False
        if not inst_ip:
            log.error( "Instance '%s' IP not retrieved! Not adding instance to SGE exec host pool." % inst.id )
            return False
        if inst_ip not in allhosts_out:
            log.info( "Adding instance %s to SGE Execution Host list" % inst.id )
            time.sleep(10) # Wait in hope that SGE processed last host addition
            stderr = None
            stdout = None
            proc = subprocess.Popen( 'export SGE_ROOT=%s; . $SGE_ROOT/default/common/settings.sh; %s/bin/lx24-amd64/qconf -ah %s' % (paths.P_SGE_ROOT, paths.P_SGE_ROOT, inst_ip), shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE )
            std = proc.communicate()
            if std[0]:
                stdout = std[0]
            if std[1]:
                stderr = std[1]
            log.debug( "stdout: %s" % stdout )
            log.debug( "stderr: %s" % stderr )
            # TODO: Should be looking at return code and use stdout/err just for info about the process progress...
            # It seems that SGE prints everything to stderr
            if stderr is None or 'already exists' in stderr or 'added to administrative host list' in stderr:
                log.debug( "Successfully added instance '%s' (w/ private IP: %s) as administrative host." % (inst.id, inst.private_ip ))
            else:
                error = True
                log.debug( "Encountered problems adding instance '%s' as administrative host: %s" % ( inst.id, stderr ) )
            # if ret_code == 0:
            #     log.debug( "Successfully added instance '%s' as administrative host." % inst.id )
            # else:
            #     error = True
            #     log.error( "Failed to add instance '%s' as administrative host." % inst.id )
            
            # Create temp dir to hold all worker host configuration files
            host_conf_dir = "%s/host_confs" % paths.P_SGE_ROOT
            if not os.path.exists( host_conf_dir ):
                subprocess.call( 'mkdir -p %s' % host_conf_dir, shell=True )
                os.chown( host_conf_dir, pwd.getpwnam( "sgeadmin" )[2], grp.getgrnam( "sgeadmin" )[2] )
            host_conf = host_conf_dir + '/' + str( inst.id )
            f = open( host_conf, 'w' )
            print >> f, templates.SGE_HOST_CONF_TEMPLATE % ( inst_ip )
            f.close()
            os.chown( host_conf, pwd.getpwnam( "sgeadmin" )[2], grp.getgrnam( "sgeadmin" )[2] )
            log.debug( "Created SGE host configuration template as file '%s'." % host_conf )
            # Add worker instance as execution host to SGE
            proc = subprocess.Popen( 'export SGE_ROOT=%s; . $SGE_ROOT/default/common/settings.sh; %s/bin/lx24-amd64/qconf -Ae %s' % (paths.P_SGE_ROOT, paths.P_SGE_ROOT, host_conf), shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE )
            stderr = None
            stdout = None
            std = proc.communicate()
            if std[0]:
                stdout = std[0]
            if std[1]:
                stderr = std[1]
            log.debug( "Adding SGE execution host stdout (instance: '%s', private IP: '%s'): %s" % (inst.id, inst.private_ip, stdout))
            log.debug( "Adding SGE execution host stderr (instance: '%s', private IP: '%s'): %s" % (inst.id, inst.private_ip, stderr))
            # TODO: Should be looking at return code and use stdout/err just for info about the process progress...
            if stderr is None or 'added' in stderr:
                log.debug( "Successfully added instance '%s' as execution host." % inst.id )
            elif 'already exists' in stderr:
                log.debug( "Instance '%s' already exists in exechost list: %s" % ( inst.id, stderr ) )
            else:
                error = True
                log.debug( "Encountered problems adding instance '%s' as execution host: %s" % ( inst.id, stderr ) )
            
            # Check if given instance's hostname is in @allhosts list and add it if it's not
            now = datetime.datetime.utcnow()
            ah_file = '/tmp/ah_add_' + now.strftime("%H_%M_%S")
            self.write_allhosts_file( filename=ah_file, to_add = inst_ip)
            misc.run('export SGE_ROOT=%s; . $SGE_ROOT/default/common/settings.sh; %s/bin/lx24-amd64/qconf -Mhgrp %s' % (paths.P_SGE_ROOT, paths.P_SGE_ROOT, ah_file),"Problems updating @allhosts aimed at removing '%s'" % inst.id, "Successfully updated @allhosts to remove '%s'" % inst.id)
            
            # On instance reboot, SGE might have already been configured for given instance and this
            # process will fail although instance may register fine with SGE...
            if error is False:
                log.info( "Successfully added instance '%s' to SGE" % inst.id )
        else:
            log.info( "Instance '%s' already in SGE's @allhosts" % inst.id )
        
        return True
    
    def stop_sge( self ):
        log.info( "Stopping SGE." )
        for inst in self.app.manager.worker_instances:
            self.remove_sge_host( inst )
        misc.run('export SGE_ROOT=%s; . $SGE_ROOT/default/common/settings.sh; %s/bin/lx24-amd64/qconf -km' % (paths.P_SGE_ROOT, paths.P_SGE_ROOT), "Problems stopping SGE master", "Successfully stopped SGE master." )
    
    # def write_allhosts_file_NEW_not_working(self, filename = '/tmp/ah', to_add = None, to_remove = None):
    #     ahl = []
    #     for inst in self.worker_instances:
    #         log.debug( "Adding instance IP '%s' to SGE's group config file '%s'" % ( inst.get_private_ip(), filename ) )
    #         ahl.append(inst.private_ip)
    #         
    #     # For comparisson purposes, make sure all elements are lower case
    #     for i in range(len(ahl)):
    #         ahl[i] = ahl[i].lower()
    #
    #     # Now reasemble and save to file 'filename'
    #     if len(ahl) > 0:
    #         new_allhosts = 'group_name @allhosts \n'+'hostlist ' + ' \\\n\t '.join(ahl) + ' \\\n'
    #     else:
    #         new_allhosts = 'group_name @allhosts \nhostlist NONE\n'
    #     f = open( filename, 'w' )
    #     f.write( new_allhosts )
    #     f.close()
    #     log.debug("new_allhosts: %s" % new_allhosts)
    #     log.debug("New SGE @allhosts file written successfully to %s." % filename)
    
    def write_allhosts_file(self, filename = '/tmp/ah', to_add = None, to_remove = None):
        proc = subprocess.Popen( "export SGE_ROOT=%s; . $SGE_ROOT/default/common/settings.sh; %s/bin/lx24-amd64/qconf -shgrp @allhosts" % (paths.P_SGE_ROOT, paths.P_SGE_ROOT), shell=True, stdout=subprocess.PIPE )
        allhosts_out = proc.communicate()[0]
        # Parsed output is in all lower case so standardize now
        try:
            to_add = to_add.lower()
        except AttributeError: # Means, value is None
            pass
        try:
            to_remove = to_remove.lower()
        except AttributeError: # Means, value is None
            pass
        
        ahl = allhosts_out.split()
        if 'NONE' in ahl:
            ahl.remove( 'NONE' )
        if 'hostlist' in ahl:
            ahl.remove( 'hostlist' )
        if '@allhosts' in ahl:
            ahl.remove( '@allhosts' )
        if 'group_name' in ahl:
            ahl.remove( 'group_name' )            
        while '\\' in ahl: # remove all backslashes
            ahl.remove('\\')
        # For comparisson purposes, make sure all elements are lower case
        for i in range(len(ahl)):
            ahl[i] = ahl[i].lower()
        # At this point we have a clean list of instances
        log.debug( 'ahl: %s' % ahl )
        log.debug( "to_add: '%s'" % to_add )
        log.debug( "to_remove: '%s'" % to_remove )
        
        if to_add is not None:
            log.debug( "Adding instance IP '%s' to SGE's group config file %s" % ( to_add, filename ) )
            ahl.append(to_add)
        if to_remove is not None and to_remove in ahl:
            log.debug( "Removing instance IP '%s' from SGE's group config file %s" % ( to_remove, filename ) )
            ahl.remove(to_remove)
        elif to_remove is not None:
            log.debug( "Instance's IP '%s' not matched in allhosts list: %s" % ( to_remove, ahl ) )
        
        # Now reasemble and save to file 'filename'
        if len(ahl) > 0:
            new_allhosts = 'group_name @allhosts \n'+'hostlist ' + ' \\\n\t '.join(ahl) + ' \\\n'
        else:
            new_allhosts = 'group_name @allhosts \nhostlist NONE\n'
        with open(filename, 'w') as f:
            f.write(new_allhosts)
        log.debug("new_allhosts: %s" % new_allhosts)
        log.debug("New SGE @allhosts file written successfully to %s." % filename)
    
    def remove_sge_host( self, inst ):
        log.info( "Removing instance '%s' from SGE" % inst.id )
        log.debug("Removing instance '%s' from SGE administrative host list" % inst.id )
        ret_code = subprocess.call( 'export SGE_ROOT=%s; . $SGE_ROOT/default/common/settings.sh; %s/bin/lx24-amd64/qconf -dh %s' % (paths.P_SGE_ROOT, paths.P_SGE_ROOT, inst.private_ip), shell=True )
        
        inst_ip = inst.get_private_ip()
        log.debug( "Removing instance '%s' with FQDN '%s' from SGE execution host list (including @allhosts)" % ( inst.id, inst_ip) )
        now = datetime.datetime.utcnow()
        ah_file = '/tmp/ah_remove_' + now.strftime("%H_%M_%S")
        self.write_allhosts_file(filename=ah_file, to_remove=inst_ip)
        
        ret_code = subprocess.call( 'export SGE_ROOT=%s; . $SGE_ROOT/default/common/settings.sh; %s/bin/lx24-amd64/qconf -Mhgrp %s' % (paths.P_SGE_ROOT, paths.P_SGE_ROOT, ah_file), shell=True )
        if ret_code == 0:
            log.info( "Successfully updated @allhosts to remove '%s'" % inst.id )
        else:
            log.debug( "Problems updating @allhosts aimed at removing '%s'; process returned code '%s'" % ( inst.id, ret_code ) )  
        
        proc = subprocess.Popen( 'export SGE_ROOT=%s; . $SGE_ROOT/default/common/settings.sh; %s/bin/lx24-amd64/qconf -de %s' % (paths.P_SGE_ROOT,paths.P_SGE_ROOT, inst.private_ip), shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE )
        stderr = None
        std = proc.communicate()
        if std[1]:
            stderr = std[1]
        # TODO: Should be looking at return code and use stdout/err just for info about the process progress...
        if stderr is None or 'removed' in stderr:
            ret_code = subprocess.call( 'export SGE_ROOT=%s; . $SGE_ROOT/default/common/settings.sh; /opt/sge/bin/lx24-amd64/qconf -dconf %s' % (paths.P_SGE_ROOT, inst.private_ip), shell=True )
            log.debug( "Successfully removed instance '%s' with IP '%s' from SGE execution host list." % ( inst.id, inst_ip ) )
            return True
        elif 'does not exist' in stderr:
            log.debug( "Instance '%s' with IP '%s' not found in SGE's exechost list: %s" % ( inst.id, inst_ip, stderr ) )
            return True
        else:
            log.debug( "Failed to remove instance '%s' with FQDN '%s' from SGE execution host list: %s" % ( inst.id, inst_ip, stderr ) )
            return False
    
    def check_sge(self):
        """Check if SGE qmaster is running and a sample job can be successfully run.
        :rtype: bool
        :return: True if the daemon is running and a sample job can be run,
                 False otherwise.
        """
        qstat_out = commands.getoutput('%s - galaxy -c "export SGE_ROOT=%s;\
            . %s/default/common/settings.sh; \
            %s/bin/lx24-amd64/qstat -f | grep all.q"' 
            % (paths.P_SU, paths.P_SGE_ROOT, paths.P_SGE_ROOT, paths.P_SGE_ROOT))
        qstat_out = qstat_out.split('\n')
        cleaned_qstat_out = []
        for line in qstat_out:
            if line.startswith('all.q'):
                cleaned_qstat_out.append(line)
        log.debug("qstat: %s" % cleaned_qstat_out)
        if len(cleaned_qstat_out) > 0: #i.e., at least 1 exec host exists
            # At least 1 exec host exists, assume it will accept jobs
            return True
        elif self.app.manager.get_num_available_workers() == 0:
            # Daemon running but no ready worker instances yet so assume all OK
            return True
        else:
            log.warning("\tNo machines available to test SGE (qstat: %s)." % cleaned_qstat_out)
            return False
    
    def status(self):
        if self.state==service_states.SHUTTING_DOWN or \
           self.state==service_states.SHUT_DOWN or \
           self.state==service_states.UNSTARTED or \
           self.state==service_states.WAITING_FOR_USER_ACTION:
            pass
        elif self._check_daemon('sge'):
            if self.check_sge():
                self.state = service_states.RUNNING
        elif self.state!=service_states.STARTING:
            log.error("SGE error; SGE not runnnig")
            self.state = service_states.ERROR
    
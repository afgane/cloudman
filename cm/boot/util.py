import os
import subprocess


def _run(log, cmd):
    process = subprocess.Popen(cmd, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    stdout, stderr = process.communicate()
    if process.returncode == 0:
        log.debug("Successfully ran '%s'" % cmd)
        if stdout:
            return stdout
        else:
            return True
    else:
        log.error("Error running '%s'. Process returned code '%s' and following stderr: %s"
                  % (cmd, process.returncode, stderr))
        return False


def _is_running(log, process_name):
    """
    Check if a process with ``process_name`` is running. Return ``True`` is so,
    ``False`` otherwise.
    """
    p = _run(log, "ps xa | grep {0} | grep -v grep".format(process_name))
    return p and process_name in p


def _make_dir(log, path):
    log.debug("Checking existence of directory '%s'" % path)
    if not os.path.exists(path):
        try:
            log.debug("Creating directory '%s'" % path)
            os.makedirs(path, 0755)
            log.debug("Directory '%s' successfully created." % path)
        except OSError, e:
            log.error("Making directory '%s' failed: %s" % (path, e))
    else:
        log.debug("Directory '%s' exists." % path)


def _which(program, additional_paths=[]):
    """
    Like *NIX's ``which`` command, look for ``program`` in the user's $PATH
    and ``additional_paths`` and return an absolute path for the ``program``. If
    the ``program`` was not found, return ``None``.
    """
    def _is_exec(fpath):
        return os.path.isfile(fpath) and os.access(fpath, os.X_OK)

    fpath, fname = os.path.split(program)
    if fpath:
        if _is_exec(program):
            return program
    else:
        for path in os.environ["PATH"].split(os.pathsep) + additional_paths:
            path = path.strip('"')
            exec_file = os.path.join(path, program)
            if _is_exec(exec_file):
                return exec_file
    return None


def _nginx_executable():
    """
    Get the path of the nginx executable
    """
    possible_paths = ['/usr/sbin/nginx', '/usr/nginx/sbin/nginx',
                     '/opt/galaxy/pkg/nginx/sbin/nginx']
    return _which('nginx', possible_paths)


def _nginx_conf_dir():
    """
    Look around at possible nginx directory locations (from published
    images) and resort to a file system search
    """
    for path in ['/etc/nginx', '/usr/nginx', '/opt/galaxy/pkg/nginx']:
        if os.path.exists(path):
            return path
    return ''


def _nginx_conf_file():
    """
    Get the path of the nginx conf file, namely ``nginx.conf``
    """
    path = os.path.join(_nginx_conf_dir(), 'nginx.conf')
    if os.path.exists(path):
        return path
    # Resort to a full file system search
    cmd = 'find / -name nginx.conf'
    output = _run(cmd)
    if isinstance(output, str):
        path = output.strip()
        if os.path.exists(path):
            return path
    return None

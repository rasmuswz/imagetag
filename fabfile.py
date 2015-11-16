from fabric.contrib.project import rsync_project
from fabric.contrib.files import exists
from fabric.api import *
from getpass import getpass
import os
import subprocess


__author__ = 'rwl'

def get_tag():
    return local("git rev-parse --short HEAD", capture=True).strip();

@task
def build():
    tag=get_tag();
    with shell_env(GOPATH=os.path.realpath("goimagetag")):
        local("go install main")
        local("tar cmvzf ../goimagetag_" + tag + ".tgz --exclude .git ./src");
        local("tar cmvzf ../dart_" + tag + ".tgz --exclude .git ../build/web");



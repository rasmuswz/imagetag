from fabric.contrib.project import rsync_project
from fabric.contrib.files import exists
from fabric.api import *
from getpass import getpass
import os
import os.path
import subprocess


__author__ = 'rwl'

def get_tag():
    return local("git rev-parse --short HEAD", capture=True).strip();

def build_dart(tag):
    dartfile="dart_"+tag+".tgz"
#    if not os.path.isfile(dartfile):
    local("pub get")
    local("pub build --mode=debug   ")
    local("tar cmvzf " + dartfile+" --exclude .git build/web");
    return dartfile;


def build_go(tag):
    gofile="goimagetag_" + tag + ".tgz"
    with shell_env(GOPATH=os.path.realpath("goimagetag")):
        local("go get github.com/disintegration/imaging")
        local("go get github.com/go-sql-driver/mysql")
        local("go install main")
        local("tar cmvzf "+gofile+" --exclude .git ./goimagetag/src");
    return gofile;

def pack_and_send_scripts(tag,deploydir):
    scriptFile="scripts_"+tag+".tgz";
    local("tar cmvzf "+scriptFile+" --exclude .git ./scripts");
    put(scriptFile,".")
    run("tar xmfz "+scriptFile)

def restart(deploydir):
    local("ssh "+env.host_string+" \"cd "+deploydir+" && scripts/imagetag.sh restart /usr/local/data/3TB/Billeder\"");


@task
@hosts(["rwz@raffinit.com"])
def restart_wz_gl():
    tag=get_tag()
    deploydir = "/var/www/online/wz.gl/imagetag_"+tag;
    restart(deploydir)

@task
@hosts(["rwz@raffinit.com"])
def deploy_wz_gl():
    tag=get_tag()
    gofile=build_go(tag);
    dartfile=build_dart(tag)

    deploydir = "/var/www/online/wz.gl/imagetag_"+tag;
    run("mkdir -p "+deploydir);
    put(gofile,deploydir+"/"+gofile)
    put(dartfile,deploydir+"/"+dartfile)
    with cd(deploydir):
        run("tar xmfz "+gofile)
        run("tar xmfz "+dartfile)
        if not exists("go1.5.1.freebsd-amd64.tar.gz"):
            run('wget https://storage.googleapis.com/golang/go1.5.1.freebsd-amd64.tar.gz')
        run("tar xmfz go1.5.1.freebsd-amd64.tar.gz")
        with shell_env(GOROOT=deploydir+"/go",GOPATH=deploydir+"/goimagetag"):
            prefix = "export PATH=${PWD}/go/bin:${PATH} && export GOROOT=${PWD}/go "
            run(prefix+ "&& go get github.com/disintegration/imaging")
            run(prefix+ "&& go get github.com/go-sql-driver/mysql")
            run(prefix+" && go install main");
            pack_and_send_scripts(tag,deploydir)
    restart(deploydir)

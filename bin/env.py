import json
import os

error_msg = '...'

def get_error():
    return error_msg

instance_name = None

def init(json_options):
    jops = json.loads(json_options)
    global instance_name
    instance_name = jops['configuration']['instance_name']
    return True

def finish():
    return True

def setup():
    this_dir = os.path.dirname(__file__)
#   script_path = this_dir + '/run_script.sh'
    script_path =  os.environ['TRAKT_BIN'] + '/run_script.sh'
    cmd = script_path + ' ' + instance_name
    r = os.system(cmd)
    return r == 0

def teardown():
    return True



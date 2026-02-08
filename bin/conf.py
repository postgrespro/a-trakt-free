import json
import os
import sys
import traceback
import subprocess

def transform_options(ops_json):
    try:
        jops = json.loads(ops_json)
        instance_name = jops['configuration']['instance_name']
        this_dir = os.path.dirname(__file__)
#       script_path = this_dir + '/init_script.sh'
        script_path =  os.environ['TRAKT_BIN'] + '/init_script.sh'

        pr = subprocess.Popen([script_path, instance_name], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        pr.wait()
        assert pr.returncode == 0
        output = pr.stdout.read()
        for line in output.split():
            ls = line.split('=')
            assert len(ls) == 2
            var_name = ls[0].strip()
            var_value = ls[1].strip()
            os.environ[var_name] = var_value
        return json.dumps(jops)
    except Exception as ex:
        print("EXCEPTION!")
        traceback.print_exc()
        return None


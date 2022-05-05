# setup program if run for first time
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
new_cmd="alias quick_connect=${SCRIPT_DIR}/quick_connect.sh"
echo "${new_cmd}" >> ~/.bashrc

resources="/Volumes/My Shared Files/Resources/"

# Set up GitLab Runner
runner_exec_file="$resources/gitlab-runner-darwin-arm64"
token_file="$resources/RUNNER_TOKEN"
endpoint_file="$resources/RUNNER_ENDPOINT_URL"

sudo mkdir -p /usr/local/bin
sudo mv "$runner_exec_file" /usr/local/bin/gitlab-runner
sudo chmod +x /usr/local/bin/gitlab-runner

# Bypass Apple security measures: Can't be opened because Apple cannot check it for malicious software
sudo xattr -d com.apple.quarantine /usr/local/bin/gitlab-runner

# Run the Runner
token=$(cat "$token_file")
endpoint=$(cat "$endpoint_file")

/usr/local/bin/gitlab-runner run-single -u $endpoint -t $token --executor shell --env "FF_RESOLVE_FULL_TLS_CHAIN=1" --max-builds 1

# Shut down the VM after build is completed
sudo shutdown -r now
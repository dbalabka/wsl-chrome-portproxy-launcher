Plan

- Define a bash script that runs in WSL and determines the Windows host address automatically from `ip route` output.
- Add checks for existing portproxy forwarding on port 9222 via `netsh interface portproxy show all`; if missing, print the admin PowerShell command to create it.
- Add checks for the Windows firewall rule “Chrome Remote Debug” on port 9222 via PowerShell; if missing, prompt the admin PowerShell command to add it.
- Verify `socat` availability in WSL and install it if absent.
- Start `socat` in the background forwarding WSL port 9222 to the Windows host port 9222.
- Launch Chrome on Windows through PowerShell with the required remote debugging flags and a temporary profile directory.

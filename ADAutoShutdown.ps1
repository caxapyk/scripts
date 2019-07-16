# Run this PS script each hour at 
# AD Server scheduler 
#
# Alexander Sakharuk <saharuk.alexander@gmail.com>
# https://github.com/caxapyk
#

$DN = "CN=Computers, DC=arsenal-orel, DC=ru"

for($i=0; $i -le 23; $i++){
    $date = Get-Date -UFormat '%H'
    # if current hour equals to group shutdown time do...
    if ($i -eq $date) {
        # try to find time groups AutoShutdownAt[i]
        try
        {
            $ComputersInGroup = Get-ADGroupMember -Identity  "CN=AutoShutdownAt$i, $DN" | select name -ExpandProperty name
            Write-Host "Policy group AutoShutdownAt$i found."
            # shutdown immediately if computers found in group
            If ($ComputersInGroup) {
                $ComputersInGroup | ForEach-Object -Process {
                    if (Test-Connection -ComputerName $_ -Count 1 -Quiet) {
                        Write-Host ("    ", $_,  "shutting down...")
                        try
                        {
                            Stop-Computer -ComputerName $_ -Force -ErrorAction Stop
                        } catch {
                            Write-Host  ("    ", $_.Exception.Message)
                        }
                    } else {
                        Write-Host ("    ", $_,  "is not avaible!")
                    }
                }
            } else {
                Write-Host "    Computers in Policy group AutoShutdownAt$i not found."
            }
            Remove-Variable ComputersInGroup
        } catch {
            Write-Host "Policy group AutoShutdownAt$i not found, skipping..."
        }
    }
}

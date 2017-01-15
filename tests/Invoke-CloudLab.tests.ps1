param (
    [String]$loadbalanceruri,
    [string[]]$vmIPs
)

Describe "Answers from individual VM IPs" {
    Context "Http server" {
        $vmIPs | ForEach-Object {
            $web = Test-NetConnection $_ -CommonTCPPort HTTP
            It "VM $_ answer on port 80" {
                $web.TcpTestSucceeded  | Should Be 'True'
            }
        }
    }
    Context "PHP serverr" {
        $vmIPs | ForEach-Object {
            $php = Invoke-WebRequest -Uri ($_ + '/phpinfo.php') -DisableKeepAlive
            It "VM $_ PHP info page" {
                $php.StatusCode  | Should Be 200
            }
        }
    }
}
Describe "Answer through Load Balancer" {
    Context "Http server" {
        $web = Test-NetConnection $loadbalanceruri -CommonTCPPort HTTP
        It "Http answer through loadbalancer" {
            $web.TcpTestSucceeded  | Should Be 'True'
        }
    }
    Context "PHP server" {
         $php = Invoke-WebRequest -Uri ($($loadbalanceruri) + '/phpinfo.php') -DisableKeepAlive
        It "PHP info page through LB" {
            $php.StatusCode | Should Be 200
        }
    }
}


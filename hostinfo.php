<!DOCTYPE HTML>
<html>
<head>
<title>EC2 Instance Meta-data Page built by PHP</title>
<style>
hr {color:sienna;}
body {background-color:#ffffff;}
</style>
</head>
<body>
<a href="http://aws.amazon.com"><img src="http://d36cz9buwru1tt.cloudfront.net/Powered-by-Amazon-Web-Services.jpg" alt="Amazon Web Services"></a> 
<br>
<br>
<?php
    $az=shell_exec('wget -q -O - http://169.254.169.254/latest/meta-data/placement/availability-zone');
    $hostname=shell_exec('wget -q -O - http://169.254.169.254/latest/meta-data/local-hostname');
    $ami=shell_exec('wget -q -O - http://169.254.169.254/latest/meta-data/ami-id');
    $instance=shell_exec('wget -q -O - http://169.254.169.254/latest/meta-data/instance-id');
    $type=shell_exec('wget -q -O - http://169.254.169.254/latest/meta-data/instance-type');
    echo date('h:i:s') . "<br>\n";
    echo "Host information = ",php_uname(),"<br>\n";
    echo "Hostname = $hostname<br>\n";
    echo "AMI Id = $ami<br>\n";
    echo "Instance Type = $type<br>\n";
    echo "Instance Id = $instance<br>\n";
    // current time
    //echo date('h:i:s') . "<br>\n";

    // sleep for 30 seconds
    //sleep(30);

    // wake up !
    //echo date('h:i:s') . "<br>\n";

?>
</body>
</html>

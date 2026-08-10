# EasyCart — Zero Trust Private Cloud Architecture

MSc Research Project, Cloud Computing, National College of Ireland.
Author: Melwin Joel (x24265438). Supervisor: Dr. Ahmed Makki.

EasyCart is a multi-tier e-commerce application deployed as a fully private,
forensically-instrumented Zero Trust architecture on AWS. Four private VPCs
(hub, frontend, app, database) are connected via a Transit Gateway. There is
no internet gateway, no public IP, and no open administration port anywhere
in the deployment. Access is provided through three independently
authenticated paths: SSM Session Manager for operators, Client VPN for end
users, and a private JWT-authenticated API Gateway for services.

Full design rationale and experiments are in the project report. Step-by-step
deployment commands are in the Configuration Manual.


# AWS VPC with Bastion Host (Terraform)

Two-AZ VPC in `eu-central-1` built with Terraform: public and private subnets, a bastion host, an optional NAT Gateway, and security groups for an Application Load Balancer and Auto Scaling group.

## Architecture

~~~
                         Internet
                            |
                     Internet Gateway
                            |
        +------ public route table (0.0.0.0/0 -> IGW) ------+
        |                                                    |
  public 10.0.1.0/24 (AZ a)                    public 10.0.2.0/24 (AZ b)
    bastion host, NAT Gateway (optional)         ALB
        |
        |  SSH only from bastion-sg / HTTP only from alb-sg
        v
  private 10.0.11.0/24 (AZ a)                  private 10.0.12.0/24 (AZ b)
    Auto Scaling group instances                 Auto Scaling group instances
        +--- private route table (local only, or 0.0.0.0/0 -> NAT) ---+
~~~

| Security group | Inbound rules |
|---|---|
| bastion-sg | SSH 22 from my IP only |
| alb-sg | HTTP 80 from the internet |
| app-sg | SSH 22 from bastion-sg, HTTP 80 from alb-sg |

## What Terraform builds

16 resources: VPC, internet gateway, 4 subnets, 2 route tables with explicit associations, 3 security groups, and the bastion EC2 instance. With `enable_nat=true` it adds a NAT Gateway, an Elastic IP and a private route (19 total).

The launch template, Auto Scaling group, target group and ALB were built manually in the console on top of this network. Moving them into Terraform is the next step.

## Usage

~~~bash
echo "my_ip = \"$(curl -s https://checkip.amazonaws.com)/32\"" > terraform.tfvars
terraform init
terraform plan
terraform apply                          # without NAT
terraform apply -var="enable_nat=true"   # with NAT (costs money hourly)
terraform output
terraform destroy
~~~

SSH to a private instance through the bastion:

~~~bash
ssh -i ~/.ssh/KEY.pem -J ec2-user@BASTION_IP ec2-user@PRIVATE_IP
~~~

## Design decisions

- **Explicit route table associations.** No subnet relies on the main route table, so adding a route there can never expose a private subnet by accident.
- **Security groups reference each other, not IPs.** App instances accept SSH only from the bastion and HTTP only from the load balancer.
- **NAT Gateway is optional.** It costs money every hour, so it is only enabled while private instances need outbound internet.
- **IMDSv2 required** on the bastion, gp3 root volume deleted on termination.
- **Latest Amazon Linux 2023 AMI** looked up via SSM Parameter Store, never hardcoded.

## Verified

- SSH from my laptop to the bastion, and through it to a private instance with ProxyJump.
- `curl` from a private instance times out without NAT, proving the subnet is private.
- Two ASG instances in different AZs registered as healthy targets; the ALB DNS name alternates between them.

## What broke and how I fixed it

1. **Private subnet attached to the public route table**, which made it effectively public. Fixed with a dedicated private route table.
2. **Security groups created in the default VPC.** A security group's VPC can't be changed, so I recreated them in the right VPC.
3. **SSH through the bastion hung.** Ran `bash -c '</dev/tcp/IP/22'` from the bastion to separate network problems from key problems.
4. **Launch template had no AMI.** Created a new version with the AMI and pointed the ASG at the latest version, since the default version stayed at 1.
5. **ALB health checks need a web server, and installing one needs internet.** Enabled NAT, added a user-data script to the launch template, and replaced the instances with an instance refresh.
6. **Cleanup order matters.** Resources created outside Terraform (ASG, ALB, target group) must be deleted first, or `terraform destroy` gets stuck on the subnets and security groups they use.

## Cost

Without NAT, only the bastion (t3.micro and its public IPv4 address) costs money. The NAT Gateway and ALB are billed hourly, so everything is destroyed after each session.

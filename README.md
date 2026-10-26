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

24 resources, all in Terraform: VPC, internet gateway, 4 subnets, 2 route tables with explicit associations, 3 security groups, a bastion host, an optional NAT Gateway (Elastic IP, gateway, route), a launch template, a target group, an Application Load Balancer with listener, and an Auto Scaling group (2 instances across 2 AZs, ELB health checks). Without NAT it is 21 resources.

The ASG instances install Apache through the NAT Gateway at boot, so apply with `enable_nat=true`. The load balancer URL is printed as the `alb_url` output.

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
- Terminated one ASG instance by hand; the ASG launched a replacement in the same AZ within a minute while the ALB kept serving from the other.

## What broke and how I fixed it

1. **Private subnet attached to the public route table**, which made it effectively public. Fixed with a dedicated private route table.
2. **Security groups created in the default VPC.** A security group's VPC can't be changed, so I recreated them in the right VPC.
3. **SSH through the bastion hung.** Ran `bash -c '</dev/tcp/IP/22'` from the bastion to separate network problems from key problems.
4. **Launch template had no AMI.** Created a new version with the AMI and pointed the ASG at the latest version, since the default version stayed at 1.
5. **ALB health checks need a web server, and installing one needs internet.** Enabled NAT, added a user-data script to the launch template, and replaced the instances with an instance refresh.
6. **Cleanup order matters for hand-built resources.** The ASG, ALB and target group created in the console had to be deleted before `terraform destroy`, or it got stuck on the subnets and security groups they used. Moving them into Terraform fixed it: one `terraform destroy` now removes all 24 resources in the right order.

## Cost

Without NAT, only the bastion (t3.micro and its public IPv4 address) costs money. The NAT Gateway and ALB are billed hourly, so everything is destroyed after each session.

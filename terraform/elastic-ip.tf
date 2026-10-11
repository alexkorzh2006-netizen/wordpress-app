resource "aws_eip" "instance" {
  domain = "vpc"

  tags = {
    Name = "${var.project_name}-eip"
  }
}

resource "aws_eip_association" "instance" {
  allocation_id = aws_eip.instance.id
  instance_id   = aws_instance.web.id

  depends_on = [aws_internet_gateway.main]
}

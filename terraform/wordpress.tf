resource "random_password" "wordpress_admin" {
  length  = 24
  special = false
}

variable "vm_count" {
  default = 2
}

variable "admin_username" {
  default = "adminuser"
}

variable "public_key_path" {
  default = "~/.ssh/adminuser_rsa.pub"
}
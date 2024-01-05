#
# variables.tf
#

variable "api_fingerprint" {
    description = "Fingerprint of oci api private key."
    type = string
}

variable "api_private_key_path" {
    description = "The path to oci api private key."
    type = string
}

variable "tenancy_id" {
    description = "The tenancy id in which to create the resources."
    type = string
}

variable "user_id" {
    description = "The id of the user that terraform will use to create the resources."
    type = string
}

variable "root_compartment" {
    description = "The root/main compartment where the resources will be created."
    type = string  
}
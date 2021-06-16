variable "baseResourceName" {
    type = string
}
variable "botResourceGroupName" {
    type = string
}
variable "sku" {
    type = string
}
variable "botRegion" {
    type = string
}
variable "botSubscriptionID" {
    type = string
    sensitive = true
}
variable "botSubscriptionClientID" {
    type = string
    sensitive = true
}
variable "botSubscriptionClientSecret" {
    type = string
    sensitive = true
}
variable "botSubscriptionTenantID" {
    type = string
    sensitive = true
}
variable "endDate" {
    type = string
}
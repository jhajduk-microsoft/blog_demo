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
  type      = string
  sensitive = true
}
variable "botSubscriptionClientID" {
  type      = string
  sensitive = true
}
variable "botSubscriptionClientSecret" {
  type      = string
  sensitive = true
}
variable "botSubscriptionTenantID" {
  type      = string
  sensitive = true
}
variable "endDate" {
  type = string
}
variable "domainName" {
  type        = list(string)
  description = "The domain name for the app service used for the web app configuration properties."
}
variable "domain" {
  type        = string
  description = "The domain name for the app service used for the author service principal properties."
}

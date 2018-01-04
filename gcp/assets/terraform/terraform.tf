variable "env_name" {
  type = "string"
}
variable "google_project" {
  type = "string"
}
variable "google_region" {
  default = "us-central1"
}
variable "google_zone" {
  default = "us-central1-a"
}
variable "google_json_key_data" {
  type = "string"
}

provider "google" {
  credentials = "${var.google_json_key_data}"
  project     = "${var.google_project}"
  region      = "${var.google_region}"
}

resource "google_compute_address" "director" {
  name = "${var.env_name}-director-ubuntu"
}

resource "google_compute_address" "bats" {
  name = "${var.env_name}-bats-ubuntu"
}

resource "google_compute_network" "network" {
  name = "${var.env_name}-custom"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "subnetwork" {
  name          = "${var.env_name}-${var.google_region}"
  ip_cidr_range = "10.0.0.0/24"
  network       = "${google_compute_network.network.self_link}"
}

resource "google_compute_firewall" "internal" {
  name    = "${var.env_name}-internal"
  network = "${google_compute_network.network.name}"

  description = "BOSH CI Internal traffic"

  allow {
    protocol = "icmp"
  }
  allow {
    protocol = "tcp"
  }
  allow {
    protocol = "udp"
  }

  source_tags = ["${var.env_name}-internal"]
  target_tags = ["${var.env_name}-internal"]
}

resource "google_compute_firewall" "external" {
  name    = "${var.env_name}-external"
  network = "${google_compute_network.network.name}"

  description = "BOSH CI External traffic"

  allow {
    protocol = "tcp"
    ports = ["22", "443", "4222", "6868", "25250", "25555", "25777"]
  }
  allow {
    protocol = "udp"
    ports = ["53"]
  }

  target_tags = ["${var.env_name}-external"]
}

output "project_id" {
  value = "${var.google_project}"
}
output "zone" {
  value = "${var.google_zone}"
}
output "network" {
  value = "${google_compute_network.network.name}"
}
output "subnetwork" {
  value = "${google_compute_subnetwork.subnetwork.name}"
}
output "internal_cidr" {
  value = "${google_compute_subnetwork.subnetwork.ip_cidr_range}"
}
output "tags" {
  value = ["${google_compute_firewall.internal.name}","${google_compute_firewall.external.name}"]
}
output "external_ip" {
  value = "${google_compute_address.director.address}"
}
output "internal_ip" {
  value = "${cidrhost(google_compute_subnetwork.subnetwork.ip_cidr_range, 6)}"
}
output "internal_gw" {
  value = "${cidrhost(google_compute_subnetwork.subnetwork.ip_cidr_range, 1)}"
}
output "reserved_range" {
  value = "${cidrhost(google_compute_subnetwork.subnetwork.ip_cidr_range, 2)}-${cidrhost(google_compute_subnetwork.subnetwork.ip_cidr_range, 15)}"
}
output "static_range" {
  value = "${cidrhost(google_compute_subnetwork.subnetwork.ip_cidr_range, 16)}-${cidrhost(google_compute_subnetwork.subnetwork.ip_cidr_range, 30)}"
}

output "bats_external_ip" {
  value = "${google_compute_address.bats.address}"
}
output "bats_static_ip_pair" {
  value = ["${cidrhost(google_compute_subnetwork.subnetwork.ip_cidr_range, 17)}","${cidrhost(google_compute_subnetwork.subnetwork.ip_cidr_range, 18)}"]
}
output "bats_static_ip" {
  value = "${cidrhost(google_compute_subnetwork.subnetwork.ip_cidr_range, 16)}"
}

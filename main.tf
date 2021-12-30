terraform {
  required_providers {
    yandex = {
      source  = "yandex-cloud/yandex"
      version = "0.68.0"
    }
  }
}

provider "yandex" {
  token     = "AQAAAABbbCeCAATuwdgA0RU1k0v0okfVuCK0nKI"
  cloud_id  = "b1gqlrb7p6gvtjhuv1pe"
  folder_id = "b1ggp5ocil88ffdsudak"
  zone      = "ru-central1-a"
}
resource "yandex_vpc_network" "network" {
  name = "netology"
}
resource "yandex_vpc_subnet" "public-subnet" {
  name           = "public"
  v4_cidr_blocks = ["192.168.10.0/24"]
  zone           = "ru-central1-a"
  description    = "NAT instance"
  network_id     = yandex_vpc_network.network.id
}
locals {
  folder_id = "b1ggp5ocil88ffdsudak"
}

// Создание сервис аккаунта
resource "yandex_iam_service_account" "sa" {
  folder_id = local.folder_id
  name      = "account"
}

// Назначение роли
resource "yandex_resourcemanager_folder_iam_member" "sa-admin" {
  folder_id = local.folder_id
  role      = "admin"
  member    = "serviceAccount:${yandex_iam_service_account.sa.id}"
}

// Создание статического ключа доступа
resource "yandex_iam_service_account_static_access_key" "sa-static-key" {
  service_account_id = yandex_iam_service_account.sa.id
  description        = "static access key for object storage"
}

// Создание Bucket
resource "yandex_storage_bucket" "my-bucket" {
  access_key = yandex_iam_service_account_static_access_key.sa-static-key.access_key
  secret_key = yandex_iam_service_account_static_access_key.sa-static-key.secret_key
  bucket = "mixa"
}
// Загрузка файла
resource "yandex_storage_object" "mixa-b" {
  access_key = yandex_iam_service_account_static_access_key.sa-static-key.access_key
  secret_key = yandex_iam_service_account_static_access_key.sa-static-key.secret_key
  bucket = "mixa"
  key    = "netology.png"
  source = "/home/mixa/Загрузки/netology.png"

}
// Создание группы ВМ
resource "yandex_compute_instance_group" "group-test" {
  name                = "mixa-gr1"
  folder_id           = local.folder_id
  service_account_id  = "${yandex_iam_service_account.sa.id}"
  deletion_protection = false
  instance_template {
    platform_id = "standard-v1"
    resources {
      memory = 2
      cores  = 2
    }
    boot_disk {
      mode = "READ_WRITE"
      initialize_params {
        image_id = "fd827b91d99psvq5fjit"
        size     = 4
      }
    }
    network_interface {
      network_id = "${yandex_vpc_network.network.id}"
      subnet_ids = ["${yandex_vpc_subnet.public-subnet.id}"]
#      nat        = true
    }
      labels = {
      label1 = "label1-value"
      label2 = "label2-value"
    }
    metadata = {
      ssh-keys = "ubuntu:${file("~/.ssh/id_rsa.pub")}"
      user_data = "picture/x-include-https://storage.yandexcloud.net/mixa/netology.png"
    }
    network_settings {
      type = "STANDARD"
    }
  }

  variables = {
    test_key1 = "test_value1"
    test_key2 = "test_value2"
  }

  scale_policy {
    fixed_scale {
      size = 3
    }
  }

  allocation_policy {
    zones = ["ru-central1-a"]
  }

  deploy_policy {
    max_unavailable = 2
    max_creating    = 2
    max_expansion   = 2
    max_deleting    = 2
  }

  load_balancer {
    target_group_name        = "my-target-group"
    target_group_description = "load balancer target group"
  }

}


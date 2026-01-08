# Используем data source для получения образа Ubuntu
data "yandex_compute_image" "ubuntu" {
  family = "ubuntu-2204-lts"
}

# Создаем сеть и подсети
resource "yandex_vpc_network" "default" {
  name = "my-network"
}

resource "yandex_vpc_subnet" "public_a" {
  name           = "public-a"
  network_id     = yandex_vpc_network.default.id
  zone           = "ru-central1-a"
  v4_cidr_blocks = ["10.130.0.0/24"]
}

resource "yandex_vpc_subnet" "public_b" {
  name           = "public-b"
  network_id     = yandex_vpc_network.default.id
  zone           = "ru-central1-b"
  v4_cidr_blocks = ["10.130.1.0/24"]
}

resource "yandex_vpc_subnet" "private_a" {
  name           = "private-a"
  network_id     = yandex_vpc_network.default.id
  zone           = "ru-central1-a"
  v4_cidr_blocks = ["10.130.2.0/24"]
  route_table_id = yandex_vpc_route_table.nat.id
}

resource "yandex_vpc_subnet" "private_b" {
  name           = "private-b"
  network_id     = yandex_vpc_network.default.id
  zone           = "ru-central1-b"
  v4_cidr_blocks = ["10.130.3.0/24"]
  route_table_id = yandex_vpc_route_table.nat.id
}

# Создаем NAT gateway для приватных подсетей
resource "yandex_vpc_gateway" "nat_gateway" {
  name = "nat-gateway"
  shared_egress_gateway {}
}

resource "yandex_vpc_route_table" "nat" {
  name       = "nat-route-table"
  network_id = yandex_vpc_network.default.id

  static_route {
    destination_prefix = "0.0.0.0/0"
    gateway_id         = yandex_vpc_gateway.nat_gateway.id
  }
}

# Создаем группы безопасности
resource "yandex_vpc_security_group" "bastion" {
  name        = "bastion-sg"
  description = "Security group for bastion host"
  network_id  = yandex_vpc_network.default.id

  ingress {
    description    = "SSH"
    protocol       = "TCP"
    port           = 22
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description    = "Any outgoing traffic"
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "yandex_vpc_security_group" "web" {
  name        = "web-sg"
  description = "Security group for web servers"
  network_id  = yandex_vpc_network.default.id

  ingress {
    description       = "HTTP from ALB"
    protocol          = "TCP"
    port              = 80
    predefined_target = "loadbalancer_healthchecks"
  }

  ingress {
    description       = "SSH from bastion"
    protocol          = "TCP"
    port              = 22
    security_group_id = yandex_vpc_security_group.bastion.id
  }

  egress {
    description    = "Any outgoing traffic"
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "yandex_vpc_security_group" "zabbix" {
  name        = "zabbix-sg"
  description = "Security group for Zabbix"
  network_id  = yandex_vpc_network.default.id

  ingress {
    description    = "Zabbix Web UI"
    protocol       = "TCP"
    port           = 80
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description       = "SSH from bastion"
    protocol          = "TCP"
    port              = 22
    security_group_id = yandex_vpc_security_group.bastion.id
  }

  egress {
    description    = "Any outgoing traffic"
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "yandex_vpc_security_group" "elastic" {
  name        = "elastic-sg"
  description = "Security group for Elasticsearch and Kibana"
  network_id  = yandex_vpc_network.default.id

  ingress {
    description    = "Kibana"
    protocol       = "TCP"
    port           = 5601
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description       = "SSH from bastion"
    protocol          = "TCP"
    port              = 22
    security_group_id = yandex_vpc_security_group.bastion.id
  }

  egress {
    description    = "Any outgoing traffic"
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

# Создаем виртуальные машины
resource "yandex_compute_instance" "bastion" {
  name        = "bastion-host"
  platform_id = "standard-v3"
  zone        = "ru-central1-a"

  resources {
    cores  = 2
    memory = 2
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu.id
      size     = 20
    }
  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.public_a.id
    nat                = true
    security_group_ids = [yandex_vpc_security_group.bastion.id]
  }

  metadata = {
    ssh-keys = "ubuntu:${file(var.ssh_public_key_path)}"
  }
}

resource "yandex_compute_instance" "webserver" {
  count       = 2
  name        = "web-server-${count.index}"
  platform_id = "standard-v3"
  zone        = count.index == 0 ? "ru-central1-a" : "ru-central1-b"

  resources {
    cores  = 2
    memory = 2
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu.id
      size     = 20
    }
  }

  network_interface {
    subnet_id          = count.index == 0 ? yandex_vpc_subnet.private_a.id : yandex_vpc_subnet.private_b.id
    security_group_ids = [yandex_vpc_security_group.web.id]
  }

  metadata = {
    ssh-keys = "ubuntu:${file(var.ssh_public_key_path)}"
  }
}

resource "yandex_compute_instance" "zabbix" {
  name        = "zabbix-server"
  platform_id = "standard-v3"
  zone        = "ru-central1-a"

  resources {
    cores  = 4
    memory = 8
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu.id
      size     = 50
    }
  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.public_a.id
    nat                = true
    security_group_ids = [yandex_vpc_security_group.zabbix.id]
  }

  metadata = {
    ssh-keys = "ubuntu:${file(var.ssh_public_key_path)}"
  }
}

resource "yandex_compute_instance" "elasticsearch" {
  name        = "elasticsearch"
  platform_id = "standard-v3"
  zone        = "ru-central1-a"

  resources {
    cores  = 4
    memory = 8
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu.id
      size     = 50
    }
  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.public_a.id
    nat                = true
    security_group_ids = [yandex_vpc_security_group.elastic.id]
  }

  metadata = {
    ssh-keys = "ubuntu:${file(var.ssh_public_key_path)}"
  }
}

resource "yandex_compute_instance" "kibana" {
  name        = "kibana"
  platform_id = "standard-v3"
  zone        = "ru-central1-a"

  resources {
    cores  = 2
    memory = 4
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu.id
      size     = 30
    }
  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.public_a.id
    nat                = true
    security_group_ids = [yandex_vpc_security_group.elastic.id]
  }

  metadata = {
    ssh-keys = "ubuntu:${file(var.ssh_public_key_path)}"
  }
}

# Создаем Target Group
resource "yandex_alb_target_group" "web" {
  name = "web-target-group"

  dynamic "target" {
    for_each = yandex_compute_instance.webserver
    content {
      subnet_id  = target.value.network_interface[0].subnet_id
      ip_address = target.value.network_interface[0].ip_address
    }
  }
}

# Создаем Backend Group
resource "yandex_alb_backend_group" "web" {
  name = "web-backend-group"

  http_backend {
    name             = "web-backend"
    weight           = 1
    port             = 80
    target_group_ids = [yandex_alb_target_group.web.id]

    healthcheck {
      timeout          = "10s"
      interval         = "2s"
      healthcheck_port = 80
      http_healthcheck {
        path = "/"
      }
    }
  }
}

# Создаем HTTP Router
resource "yandex_alb_http_router" "web" {
  name = "web-http-router"
}

resource "yandex_alb_virtual_host" "web" {
  name           = "web-virtual-host"
  http_router_id = yandex_alb_http_router.web.id
  authority      = ["*"]

  route {
    name = "web-route"
    http_route {
      http_route_action {
        backend_group_id = yandex_alb_backend_group.web.id
        timeout          = "60s"
      }
    }
  }
}

# Создаем Application Load Balancer
resource "yandex_alb_load_balancer" "web" {
  name       = "web-alb"
  network_id = yandex_vpc_network.default.id

  allocation_policy {
    location {
      zone_id   = "ru-central1-a"
      subnet_id = yandex_vpc_subnet.public_a.id
    }
  }

  listener {
    name = "web-listener"
    endpoint {
      address {
        external_ipv4_address {
        }
      }
      ports = [80]
    }
    http {
      handler {
        http_router_id = yandex_alb_http_router.web.id
      }
    }
  }
}

# Создаем снимки дисков для всех ВМ
resource "yandex_compute_snapshot_schedule" "backup" {
  name = "daily-backup"

  schedule_policy {
    expression = "0 2 * * *" # Ежедневно в 2:00
  }

  retention_period = "168h" # 7 дней

  snapshot_count = 7

  snapshot_spec {}

  disk_ids = [
    yandex_compute_instance.bastion.boot_disk[0].disk_id,
    yandex_compute_instance.webserver[0].boot_disk[0].disk_id,
    yandex_compute_instance.webserver[1].boot_disk[0].disk_id,
    yandex_compute_instance.zabbix.boot_disk[0].disk_id,
    yandex_compute_instance.elasticsearch.boot_disk[0].disk_id,
    yandex_compute_instance.kibana.boot_disk[0].disk_id
  ]
}

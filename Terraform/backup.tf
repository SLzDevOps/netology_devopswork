resource "yandex_compute_snapshot_schedule" "weekly_backup" {
  name = "weekly-backup"
  
  schedule_policy {
    expression = "0 3 * * *"  # Каждый день в 03:00
  }

  retention_period = "168h"  # 7 дней (168 часов)
  
  snapshot_count = 7  # Максимальное количество снапшотов (последние 7)
  
  snapshot_spec {
    description = "Daily backup created by snapshot schedule"
  }

  # Диски всех ВМ для резервного копирования
  disk_ids = [
    yandex_compute_instance.bastion.boot_disk[0].disk_id,
    yandex_compute_instance.webserver[0].boot_disk[0].disk_id,
    yandex_compute_instance.webserver[1].boot_disk[0].disk_id,
    yandex_compute_instance.zabbix.boot_disk[0].disk_id,
    yandex_compute_instance.elasticsearch.boot_disk[0].disk_id,
    yandex_compute_instance.kibana.boot_disk[0].disk_id
  ]
}

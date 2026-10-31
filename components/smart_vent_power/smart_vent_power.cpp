#include "smart_vent_power.h"

#include "esphome/core/application.h"
#include "esphome/core/log.h"

namespace esphome {
namespace smart_vent_power {

static const char *const TAG = "smart_vent_power";

void SmartVentPower::setup() {
  esp_pm_config_t cfg = {};
  cfg.max_freq_mhz = this->max_freq_mhz_;
  cfg.min_freq_mhz = this->min_freq_mhz_;
  cfg.light_sleep_enable = this->light_sleep_;
  esp_err_t err = esp_pm_configure(&cfg);
  if (err != ESP_OK) {
    ESP_LOGE(TAG, "esp_pm_configure failed: %s", esp_err_to_name(err));
    this->mark_failed();
    return;
  }
  esp_pm_lock_create(ESP_PM_NO_LIGHT_SLEEP, 0, "vent_no_sleep", &this->no_sleep_lock_);
  esp_pm_lock_create(ESP_PM_CPU_FREQ_MAX, 0, "vent_cpu_max", &this->max_freq_lock_);
  this->pm_ok_ = true;

  // If something called begin_activity() before setup ran, honour it now.
  if (this->activity_count_ > 0) {
    esp_pm_lock_acquire(this->no_sleep_lock_);
    esp_pm_lock_acquire(this->max_freq_lock_);
  } else {
    App.set_loop_interval(this->idle_loop_interval_);
  }
}

void SmartVentPower::begin_activity() {
  if (this->activity_count_++ > 0)
    return;
  App.set_loop_interval(this->active_loop_interval_);
  if (this->pm_ok_) {
    esp_pm_lock_acquire(this->no_sleep_lock_);
    esp_pm_lock_acquire(this->max_freq_lock_);
  }
  ESP_LOGD(TAG, "Activity started (light sleep blocked)");
}

void SmartVentPower::end_activity() {
  if (this->activity_count_ == 0)
    return;
  if (--this->activity_count_ > 0)
    return;
  if (this->pm_ok_) {
    esp_pm_lock_release(this->max_freq_lock_);
    esp_pm_lock_release(this->no_sleep_lock_);
  }
  App.set_loop_interval(this->idle_loop_interval_);
  ESP_LOGD(TAG, "Activity finished (light sleep allowed)");
}

void SmartVentPower::dump_config() {
  ESP_LOGCONFIG(TAG,
                "Smart Vent Power:\n"
                "  Light sleep: %s\n"
                "  CPU frequency: %d-%d MHz\n"
                "  Idle loop interval: %u ms",
                YESNO(this->light_sleep_), this->min_freq_mhz_, this->max_freq_mhz_,
                (unsigned) this->idle_loop_interval_);
}

}  // namespace smart_vent_power
}  // namespace esphome

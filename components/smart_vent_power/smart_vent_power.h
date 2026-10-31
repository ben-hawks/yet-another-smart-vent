#pragma once

#include "esphome/core/component.h"

#include <esp_pm.h>

namespace esphome {
namespace smart_vent_power {

class SmartVentPower : public Component {
 public:
  void setup() override;
  void dump_config() override;
  // Run early so the PM lock exists before other components start working.
  float get_setup_priority() const override { return setup_priority::BUS; }

  void set_light_sleep(bool light_sleep) { this->light_sleep_ = light_sleep; }
  void set_max_freq_mhz(int mhz) { this->max_freq_mhz_ = mhz; }
  void set_min_freq_mhz(int mhz) { this->min_freq_mhz_ = mhz; }
  void set_idle_loop_interval(uint32_t ms) { this->idle_loop_interval_ = ms; }

  /// Keep the CPU awake at full speed (no light sleep, fast main loop).
  /// Calls nest; every begin_activity() needs a matching end_activity().
  void begin_activity();
  void end_activity();
  bool is_active() const { return this->activity_count_ > 0; }

 protected:
  bool light_sleep_{true};
  int max_freq_mhz_{160};
  int min_freq_mhz_{40};
  uint32_t idle_loop_interval_{250};
  uint32_t active_loop_interval_{16};
  int activity_count_{0};
  bool pm_ok_{false};
  esp_pm_lock_handle_t no_sleep_lock_{nullptr};
  esp_pm_lock_handle_t max_freq_lock_{nullptr};
};

}  // namespace smart_vent_power
}  // namespace esphome

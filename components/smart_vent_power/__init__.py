"""smart_vent_power: ESP-IDF power management for battery smart vents.

Enables ESP-IDF dynamic frequency scaling + automatic light sleep and gives
YAML lambdas a way to keep the CPU fully awake while the servo is moving
(LEDC PWM and ADC reads must not be interrupted by light sleep).

Usage:
  smart_vent_power:
    id: power_mgr
    light_sleep: true
    idle_loop_interval: 250ms

  lambda: 'id(power_mgr).begin_activity();'   # before moving
  lambda: 'id(power_mgr).end_activity();'     # after moving
"""

import esphome.codegen as cg
from esphome.components.esp32 import add_idf_sdkconfig_option
import esphome.config_validation as cv
from esphome.const import CONF_ID

DEPENDENCIES = ["esp32"]

CONF_LIGHT_SLEEP = "light_sleep"
CONF_MAX_CPU_FREQUENCY = "max_cpu_frequency"
CONF_MIN_CPU_FREQUENCY = "min_cpu_frequency"
CONF_IDLE_LOOP_INTERVAL = "idle_loop_interval"

smart_vent_power_ns = cg.esphome_ns.namespace("smart_vent_power")
SmartVentPower = smart_vent_power_ns.class_("SmartVentPower", cg.Component)

CONFIG_SCHEMA = cv.All(
    cv.Schema(
        {
            cv.GenerateID(): cv.declare_id(SmartVentPower),
            cv.Optional(CONF_LIGHT_SLEEP, default=True): cv.boolean,
            cv.Optional(CONF_MAX_CPU_FREQUENCY, default=160): cv.int_range(
                min=40, max=240
            ),
            cv.Optional(CONF_MIN_CPU_FREQUENCY, default=40): cv.int_range(
                min=10, max=240
            ),
            cv.Optional(
                CONF_IDLE_LOOP_INTERVAL, default="250ms"
            ): cv.positive_time_period_milliseconds,
        }
    ).extend(cv.COMPONENT_SCHEMA),
    cv.only_with_esp_idf,
)


async def to_code(config):
    var = cg.new_Pvariable(config[CONF_ID])
    await cg.register_component(var, config)
    cg.add(var.set_light_sleep(config[CONF_LIGHT_SLEEP]))
    cg.add(var.set_max_freq_mhz(config[CONF_MAX_CPU_FREQUENCY]))
    cg.add(var.set_min_freq_mhz(config[CONF_MIN_CPU_FREQUENCY]))
    cg.add(var.set_idle_loop_interval(config[CONF_IDLE_LOOP_INTERVAL]))

    add_idf_sdkconfig_option("CONFIG_PM_ENABLE", True)
    if config[CONF_LIGHT_SLEEP]:
        # Let the idle task enter light sleep between FreeRTOS ticks.
        add_idf_sdkconfig_option("CONFIG_FREERTOS_USE_TICKLESS_IDLE", True)
        # Allow the 802.15.4 (Thread) radio to sleep together with the CPU.
        add_idf_sdkconfig_option("CONFIG_IEEE802154_SLEEP_ENABLE", True)

<?php
// This file is part of Moodle - http://moodle.org/
//
// Moodle is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Moodle is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with Moodle.  If not, see <http://www.gnu.org/licenses/>.

/**
 * Library functions for theme_lambda_child.
 *
 * @package    theme_lambda_child
 * @copyright  2026 Japan Ingressa Co., Ltd.
 * @license    http://www.gnu.org/copyleft/gpl.html GNU GPL v3 or later
 */

defined('MOODLE_INTERNAL') || die();

/**
 * Returns the main SCSS content.
 *
 * @param theme_config $theme The theme config object.
 * @return string SCSS content.
 */
function theme_lambda_child_get_main_scss_content($theme) {
    global $CFG;
    $scss = file_get_contents($CFG->dirroot . '/theme/lambda_child/scss/preset/default.scss');
    return $scss;
}

/**
 * Returns pre-SCSS (variables, etc.).
 *
 * @param theme_config $theme The theme config object.
 * @return string Pre-SCSS content.
 */
function theme_lambda_child_get_pre_scss($theme) {
    return '';
}

/**
 * Returns extra SCSS (appended after main).
 *
 * @param theme_config $theme The theme config object.
 * @return string Extra SCSS content.
 */
function theme_lambda_child_get_extra_scss($theme) {
    return '';
}

/**
 * Get precompiled CSS.
 *
 * @param theme_config $theme The theme config object.
 * @return string Compiled CSS.
 */
function theme_lambda_child_get_precompiled_css($theme) {
    global $CFG;
    return '';
}

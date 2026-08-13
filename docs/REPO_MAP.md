# 项目符号地图（REPO_MAP）— GDScript 类/信号/函数索引

> 自动生成：`python wanjie/tools/gen_repo_map.py`（Aider repo map 思想，AI 上下文加速）。
> 统计：126 个文件。改代码前先在此定位目标符号，再定向读取。

## resources/data/

### resources/data/ability_data.gd (`AbilitySystemData`)

- class_name **AbilitySystemData**
- func `add_skill` (L60)
- func `add_skill_simple` (L91)
- func `initialize_combat_defaults` (L98)
- func `add_growth_path` (L122)
- func `add_growth_stage` (L133)
- func `add_status_effect` (L147)
- func `get_skills_by_category` (L162)
- func `get_skills_by_sub_type` (L170)
- func `get_skills_by_school` (L178)
- func `get_skill` (L186)
- func `get_skill_name` (L193)
- func `get_element_modifier` (L200)
- func `get_skill_summary` (L207)

### resources/data/combat_data.gd (`CombatSystemData`)

- class_name **CombatSystemData**
- func `add_enemy_template` (L23)
- func `add_npc` (L43)
- func `add_battle_config` (L59)
- func `get_enemy_template` (L74)
- func `get_enemy_name` (L81)
- func `get_npc` (L88)
- func `get_npc_name` (L95)
- func `get_battle_config` (L102)
- func `get_all_enemy_ids` (L109)
- func `get_all_npc_ids` (L116)

### resources/data/economy_data.gd (`EconomySystemData`)

- class_name **EconomySystemData**
- func `add_currency` (L30)
- func `add_resource` (L41)
- func `add_market` (L52)
- func `add_market_good` (L64)
- func `get_currency_name` (L76)
- func `get_resource_name` (L83)
- func `calculate_market_price` (L90)

### resources/data/event_data.gd (`EventSystemData`)

- class_name **EventSystemData**
- func `add_story_event` (L28)
- func `add_choice` (L45)
- func `add_condition` (L56)
- func `add_random_event` (L63)
- func `add_event_chain` (L76)
- func `get_story_event` (L87)
- func `get_all_event_ids` (L94)
- func `has_prerequisite` (L101)

### resources/data/quest_data.gd (`QuestSystemData`)

- class_name **QuestSystemData**
- func `add_quest` (L25)
- func `add_objective` (L43)
- func `set_rewards` (L57)
- func `add_quest_chain` (L70)
- func `get_quest` (L79)
- func `get_quest_name` (L86)
- func `get_quests_by_type` (L93)
- func `get_all_quest_ids` (L101)

### resources/data/save_data.gd (`SaveData`)

- class_name **SaveData**
- func `get_display_info` (L38)
- func `get_game_time_display` (L57)
- func `create_new` (L69)

### resources/data/skill_data_init.gd (`SkillDataInit`)

- class_name **SkillDataInit**
- func `initialize` (L8)

### resources/data/user_data.gd (`UserData`)

- class_name **UserData**
- func `reset_to_defaults` (L69)
- func `to_dict` (L81)
- func `from_dict` (L116)
- func `get_inspiration_display` (L151)
- func `get_creation_energy_display` (L155)
- func `can_enter_script` (L159)
- func `consume_inspiration` (L163)
- func `can_create_script` (L170)
- func `consume_creation_energy` (L174)

### resources/data/world_script_data.gd (`WorldScriptData`)

- class_name **WorldScriptData**
- func `ensure_subsystems` (L56)
- func `generate_id` (L73)
- func `get_tags_display` (L77)
- func `get_status_display` (L81)

### resources/data/worldview_data.gd (`WorldviewData`)

- class_name **WorldviewData**
- func `add_era` (L45)
- func `add_timeline_entry` (L55)
- func `add_rule` (L59)
- func `add_faction` (L63)
- func `get_faction_name` (L84)

## scripts/autoload/

### scripts/autoload/dragonflame_era_data.gd (`DragonflameEraData`)

- class_name **DragonflameEraData**
- func `apply` (L7)

### scripts/autoload/editor_mode.gd (editor_mode.gd)

- signal `mode_changed`
- func `set_graph_key_state` (L39)
- func `take_graph_key_state` (L44)
- func `set_bp_view_state` (L51)
- func `take_bp_view_state` (L56)
- func `_ready` (L62)
- func `set_mode` (L70)
- func `get_mode` (L80)
- func `get_mode_name` (L84)
- func `get_mode_desc` (L88)
- func `is_visible` (L93)
- func `is_simple` (L98)
- func `is_exhaustive` (L103)

### scripts/autoload/game_manager.gd (game_manager.gd)

- signal `scripts_changed`
- signal `tab_changed`
- signal `resources_recovered`
- signal `resources_changed`
- func `_ready` (L26)
- func `save_user_data` (L89)
- func `get_script_data` (L115)
- func `get_scripts_by_tab` (L119)
- func `get_featured_scripts` (L152)
- func `get_recent_scripts` (L161)
- func `record_play` (L169)
- func `toggle_favorite` (L182)
- func `is_favorite` (L192)
- func `get_favorites` (L196)
- func `unlock_achievement` (L214)
- func `reload_scripts` (L223)
- func `set_current_tab` (L228)

### scripts/autoload/llm_client.gd (llm_client.gd)

- signal `response_received`
- signal `response_error`
- signal `stream_chunk`
- signal `stream_finished`
- signal `provider_switched`
- func `_ready` (L71)
- func `save_config` (L98)
- func `set_provider` (L115)
- func `set_api_key` (L122)
- func `get_provider_name` (L127)
- func `get_current_model` (L133)
- func `get_base_url` (L141)
- func `get_api_key` (L149)
- func `is_configured` (L153)
- func `get_available_providers` (L159)
- func `chat` (L170)
- func `chat_stream` (L179)
- func `generate` (L188)
- func `test_connection` (L196)

### scripts/autoload/save_manager.gd (save_manager.gd)

- signal `save_completed`
- signal `load_completed`
- signal `save_deleted`
- func `save_game` (L44)
- func `load_game` (L89)
- func `delete_save` (L124)
- func `list_saves` (L133)
- func `start_new_game` (L164)
- func `autosave` (L171)
- func `has_save` (L183)
- func `get_slot_info` (L188)

### scripts/autoload/scene_manager.gd (scene_manager.gd)

- signal `scene_change_started`
- signal `scene_change_completed`
- func `change_scene` (L21)
- func `go_back_to_hub` (L50)
- func `open_script_editor` (L58)
- func `enter_script` (L63)
- func `open_settings` (L75)

### scripts/autoload/script_data_manager.gd (script_data_manager.gd)

- signal `script_created`
- signal `script_updated`
- signal `script_deleted`
- signal `script_imported`
- func `_ready` (L27)
- func `get_script_dir` (L38)
- func `get_script_file` (L42)
- func `save_script` (L106)
- func `create_script` (L265)
- func `update_script` (L291)
- func `delete_script` (L297)
- func `empty_trash` (L319)
- func `find_script` (L342)
- func `export_script` (L346)
- func `clone_script` (L366)
- func `import_script` (L413)
- func `get_templates` (L450)

### scripts/autoload/script_templates.gd (`ScriptTemplates`)

- class_name **ScriptTemplates**
- func `get_template_defs` (L8)
- func `apply_template` (L29)

### scripts/autoload/tavern_manager.gd (tavern_manager.gd)

- signal `dialog_started`
- signal `dialog_ended`
- signal `message_added`
- signal `context_updated`
- func `_ready` (L31)
- func `start_dialog` (L37)
- func `end_dialog` (L51)
- func `send_message` (L58)
- func `register_world` (L83)
- func `load_world_book` (L87)
- func `get_dialog_history` (L93)
- func `clear_history` (L97)
- func `save_history` (L173)
- func `load_history` (L190)

### scripts/autoload/theme_manager.gd (theme_manager.gd)

- func `_ready` (L34)
- func `apply_font_preset` (L47)
- func `get_current_font_size` (L58)
- func `set_animations_enabled` (L62)
- func `create_anim` (L67)
- func `get_color` (L74)
- func `get_main_theme` (L90)

## scripts/editor/

### scripts/editor/ai_prompts.gd (`AIPrompts`)

- class_name **AIPrompts**
- func `worldview_user_prompt` (L26)
- func `event_user_prompt` (L51)
- func `economy_user_prompt` (L78)
- func `ability_user_prompt` (L94)
- func `general_user_prompt` (L102)
- func `quest_user_prompt` (L113)
- func `combat_user_prompt` (L123)
- func `chain_user_prompt` (L133)
- func `build_script_context` (L141)

### scripts/editor/ai_service.gd (`AIService`)

- class_name **AIService**
- signal `request_completed`
- signal `request_failed`
- signal `stream_token`
- func `init` (L23)
- func `chat_completion` (L38)
- func `structured_completion` (L60)
- func `get_config_summary` (L69)
- func `is_real_backend` (L77)
- func `update_config` (L81)

### scripts/editor/blueprint_codegen.gd (`BlueprintCodeGen`)

- class_name **BlueprintCodeGen**
- func `compile_exec_chain` (L8)

### scripts/editor/blueprint_data.gd (`BlueprintData`)

- class_name **BlueprintData**
- func `make_pin` (L46)
- func `make_graph` (L55)
- func `create_node` (L72)
- func `get_available_node_types` (L156)
- func `get_node_type_label` (L170)
- func `add_connection` (L191)
- func `remove_connection` (L206)
- func `remove_node_connections` (L217)
- func `validate_connection` (L228)
- func `get_exec_successors` (L253)
- func `get_connected_pin` (L261)
- func `get_exec_predecessor` (L270)
- func `calc_node_height` (L277)
- func `get_pin_world_pos` (L287)
- func `find_entry_nodes` (L297)
- func `declare_variable` (L305)
- func `get_var_type_string` (L309)
- func `get_pin_type_string` (L318)
- func `get_compatible_node_types` (L329)

### scripts/editor/blueprint_node_registry.gd (`BlueprintNodeRegistry`)

- class_name **BlueprintNodeRegistry**
- func `ensure_init` (L38)
- func `get_all_types` (L54)
- func `get_types_by_category` (L64)
- func `get_categories` (L75)
- func `get_definition` (L85)
- func `get_display_name` (L90)
- func `search_nodes` (L96)
- func `create_node` (L114)
- func `get_param_options` (L144)

### scripts/editor/blueprint_validator.gd (`BlueprintValidator`)

- class_name **BlueprintValidator**
- func `validate_graph` (L11)
- func `validate_node` (L65)
- func `get_summary` (L204)

### scripts/editor/condition_compiler.gd (`ConditionCompiler`)

- class_name **ConditionCompiler**
- func `make_condition` (L89)
- func `make_branch` (L104)
- func `make_action` (L113)
- func `compile_condition` (L131)
- func `compile_conditions` (L164)
- func `compile_action` (L183)
- func `compile_actions` (L226)
- func `decompile_condition` (L241)
- func `decompile_conditions` (L280)
- func `decompile_action` (L288)
- func `decompile_actions` (L349)
- func `describe_condition` (L361)
- func `describe_action` (L390)
- func `validate_condition` (L420)
- func `validate_action` (L449)

### scripts/editor/editor_node_registry.gd (`EditorNodeRegistry`)

- class_name **EditorNodeRegistry**
- func `get_all_types` (L405)
- func `get_type` (L409)
- func `has_type` (L413)
- func `get_types_by_domain` (L417)
- func `get_types_by_category` (L426)
- func `get_icon` (L440)
- func `get_default_name` (L445)
- func `get_default_props` (L450)
- func `create_node` (L459)
- func `get_signals` (L473)
- func `type_has_signal` (L493)
- func `make_default_callback` (L500)
- func `get_common_groups` (L529)
- func `parse_value` (L538)
- func `serialize_value` (L556)

### scripts/editor/editor_tab_manager.gd (`EditorTabManager`)

- class_name **EditorTabManager**
- func `open_or_activate` (L20)
- func `close_tab` (L49)
- func `switch_tab` (L71)
- func `get_active_tab` (L79)
- func `get_active_panel` (L85)
- func `set_tab_panel` (L95)
- func `get_tab_titles` (L100)
- func `get_tab_count` (L107)
- func `mark_dirty` (L111)
- func `is_path_open` (L116)
- func `set_inspector_data` (L123)
- func `get_active_inspector_data` (L129)
- func `close_all` (L136)

### scripts/editor/editor_ui_factory.gd (`EditorUIFactory`)

- class_name **EditorUIFactory**
- func `make_bg_style` (L58)
- func `make_content_style` (L67)
- func `make_nav_style` (L76)
- func `make_scroll_panel` (L87)
- func `make_vbox` (L109)
- func `add_nav_title` (L119)
- func `add_nav_btn` (L132)
- func `add_toolbar_btn` (L164)
- func `add_section_label` (L201)
- func `add_hseparator` (L222)
- func `add_info_label` (L228)
- func `add_stat_card` (L236)
- func `add_text_field` (L274)
- func `add_labeled_field` (L292)
- func `add_multiline_field` (L295)
- func `add_spin_field` (L321)
- func `add_button` (L340)
- func `field_label` (L348)
- func `add_list_editor` (L353)
- func `add_dict_editor` (L516)

### scripts/editor/editor_undo_redo.gd (`EditorUndoRedo`)

- class_name **EditorUndoRedo**
- signal `history_changed`
- func `commit` (L18)
- func `undo` (L34)
- func `redo` (L43)
- func `can_undo` (L51)
- func `can_redo` (L54)
- func `get_history` (L58)
- func `clear` (L69)
- func `get_action_count` (L74)
- func `steps_to_entry` (L78)

### scripts/editor/mud_editor.gd (mud_editor.gd)

- func `_ready` (L40)
- func `build_into` (L45)
- func `load_data` (L50)
- func `save_data` (L71)

### scripts/editor/mud_schema.gd (`MudSchema`)

- class_name **MudSchema**
- func `get_display_name` (L290)
- func `get_field_names` (L299)
- func `get_field_type` (L308)
- func `create_default_entry` (L323)
- func `get_table_group` (L337)

### scripts/editor/scene_editor_2d.gd (scene_editor_2d.gd)

- signal `scene_modified`
- signal `selection_changed`
- signal `undo_requested`
- signal `redo_requested`
- signal `save_requested`
- func `_ready` (L71)
- func `build_into` (L74)
- func `get_scene_data` (L80)
- func `get_selected_nodes` (L83)
- func `load_scene_data` (L86)
- func `reload_scene` (L92)
- func `export_json` (L97)
- func `import_json` (L100)
- func `export_tscn` (L107)

### scripts/editor/scene_editor_3d.gd (scene_editor_3d.gd)

- signal `scene_modified`
- signal `selection_changed`
- signal `undo_requested`
- signal `redo_requested`
- signal `save_requested`
- func `_ready` (L74)
- func `_process` (L77)
- func `build_into` (L87)
- func `get_scene_data` (L95)
- func `get_selected_nodes` (L99)
- func `load_scene_data` (L103)
- func `reload_scene` (L111)
- func `export_json` (L118)
- func `import_json` (L122)

### scripts/editor/script_code_editor.gd (script_code_editor.gd)

- func `_ready` (L74)
- func `build_into` (L77)
- func `load_data` (L85)
- func `get_code` (L102)
- func `apply_code` (L105)
- func `validate_code` (L123)
- func `export_code` (L135)
- func `import_code` (L145)
- func `insert_template` (L155)

### scripts/editor/script_codegen.gd (`ScriptCodeGen`)

- class_name **ScriptCodeGen**
- func `generate` (L7)
- func `parse` (L290)
- func `validate` (L543)
- func `get_template` (L584)
- func `generate_blueprint_code` (L1145)

### scripts/editor/script_editor.gd (script_editor.gd)

- func `_ready` (L147)

### scripts/editor/script_validator.gd (`ScriptValidator`)

- class_name **ScriptValidator**
- func `validate` (L14)
- func `get_report` (L33)

## scripts/editor/ide/

### scripts/editor/ide/ide_about_dialog.gd (ide_about_dialog.gd)

- func `_ready` (L9)
- func `open` (L67)

### scripts/editor/ide/ide_bottom_panel.gd (ide_bottom_panel.gd)

- signal `error_clicked`
- func `_ready` (L24)
- func `toggle_collapse` (L240)
- func `is_collapsed` (L248)
- func `log_message` (L253)
- func `log_error` (L264)
- func `log_warning` (L270)
- func `clear_errors` (L276)
- func `switch_to_tab` (L284)

### scripts/editor/ide/ide_create_node_dialog.gd (ide_create_node_dialog.gd)

- signal `node_type_confirmed`
- func `_ready` (L18)
- func `open_for_domain` (L110)

### scripts/editor/ide/ide_dock_left.gd (ide_dock_left.gd)

- func `_ready` (L13)
- func `get_scene_tree` (L50)
- func `get_file_system` (L53)
- func `set_scene_data` (L56)
- func `refresh_files` (L59)

### scripts/editor/ide/ide_dock_right.gd (ide_dock_right.gd)

- signal `node_connections_changed`
- signal `node_groups_changed`
- signal `open_script_requested`
- signal `history_entry_clicked`
- func `_ready` (L20)
- func `get_inspector` (L69)
- func `get_node_panel` (L72)
- func `get_history_panel` (L75)
- func `set_selected_nodes` (L78)
- func `set_node_panel_target` (L83)
- func `set_history` (L88)

### scripts/editor/ide/ide_file_system.gd (ide_file_system.gd)

- signal `file_selected`
- signal `file_activated`
- signal `script_activated`
- signal `text_file_activated`
- func `_ready` (L53)
- func `set_script_root` (L187)
- func `get_script_root_id` (L200)
- func `refresh` (L203)

### scripts/editor/ide/ide_history_panel.gd (ide_history_panel.gd)

- signal `history_entry_clicked`
- func `_ready` (L13)
- func `set_history` (L53)

### scripts/editor/ide/ide_inspector.gd (ide_inspector.gd)

- signal `property_changed`
- func `_ready` (L21)
- func `set_selected_nodes` (L68)

### scripts/editor/ide/ide_menu_bar.gd (ide_menu_bar.gd)

- signal `menu_action`
- func `_ready` (L11)

### scripts/editor/ide/ide_node_panel.gd (ide_node_panel.gd)

- signal `connections_changed`
- signal `groups_changed`
- signal `open_script_requested`
- func `_ready` (L29)
- func `set_node` (L172)

### scripts/editor/ide/ide_scene_tree.gd (ide_scene_tree.gd)

- signal `node_selected`
- signal `node_modified`
- func `_ready` (L58)
- func `set_scene_data` (L167)
- func `get_selected_nodes` (L171)
- func `clear_selection` (L174)

### scripts/editor/ide/ide_script_panel.gd (ide_script_panel.gd)

- signal `script_selected`
- signal `method_selected`
- func `_ready` (L25)
- func `set_scripts` (L140)
- func `set_methods` (L145)
- func `set_current_script` (L150)

### scripts/editor/ide/ide_script_view.gd (ide_script_view.gd)

- signal `text_changed`
- signal `cursor_moved`
- signal `tab_close_requested`
- func `_ready` (L24)
- func `get_code_edit` (L231)
- func `get_tab_bar` (L234)
- func `get_text` (L237)
- func `set_text` (L242)
- func `is_modified` (L248)
- func `set_modified` (L251)
- func `show_find_bar` (L254)
- func `hide_find_bar` (L265)
- func `is_find_bar_visible` (L271)
- func `goto_line` (L276)
- func `set_error_lines` (L286)
- func `set_warning_lines` (L297)

### scripts/editor/ide/ide_settings_dialog.gd (ide_settings_dialog.gd)

- signal `settings_saved`
- func `_ready` (L30)
- func `load_settings` (L38)
- func `open` (L229)

### scripts/editor/ide/ide_shortcuts_dialog.gd (ide_shortcuts_dialog.gd)

- func `_ready` (L42)
- func `open` (L75)

### scripts/editor/ide/ide_signal_dialog.gd (ide_signal_dialog.gd)

- signal `connection_confirmed`
- func `_ready` (L25)
- func `open_for_node` (L157)

### scripts/editor/ide/ide_status_bar.gd (ide_status_bar.gd)

- func `_ready` (L13)
- func `set_cursor_position` (L58)
- func `set_validation_state` (L61)
- func `set_zoom` (L80)

### scripts/editor/ide/ide_theme.gd (`IDETheme`)

- class_name **IDETheme**
- func `create_panel_style` (L89)
- func `create_flat_style` (L104)
- func `create_button_style` (L113)
- func `style_button` (L135)
- func `make_vseparator` (L149)
- func `make_hseparator` (L155)

### scripts/editor/ide/ide_top_bar.gd (ide_top_bar.gd)

- signal `workspace_selected`
- signal `run_pressed`
- signal `stop_pressed`
- signal `layout_pressed`
- func `_ready` (L18)
- func `set_active_workspace` (L152)
- func `set_scene_title` (L158)
- func `get_active_workspace` (L161)

### scripts/editor/ide/ide_workspace.gd (ide_workspace.gd)

- signal `run_requested`
- signal `workspace_changed`
- signal `editor_selection_changed`
- signal `editor_scene_modified`
- signal `editor_undo_requested`
- signal `editor_redo_requested`
- signal `editor_save_requested`
- func `_ready` (L32)
- func `switch_workspace` (L138)
- func `get_current_workspace` (L146)
- func `get_script_view` (L149)
- func `get_script_panel` (L152)
- func `get_2d_editor` (L156)
- func `load_scene_2d` (L160)
- func `get_scene_2d` (L165)
- func `get_3d_editor` (L171)
- func `load_scene_3d` (L175)
- func `get_scene_3d` (L180)
- func `toggle_script_panel` (L186)
- func `get_active_editor_domain` (L206)
- func `reload_editor_scene` (L213)

## scripts/editor/mud/

### scripts/editor/mud/mud_csv.gd (`MudCsv`)

- class_name **MudCsv**
- func `export_table` (L16)
- func `export_to_file` (L38)
- func `import_table` (L52)
- func `import_from_file` (L88)
- func `parse_csv` (L102)

### scripts/editor/mud/mud_data.gd (`MudData`)

- class_name **MudData**
- signal `table_changed`
- signal `data_reset`
- func `clear_all` (L25)
- func `clear_table` (L33)
- func `get_table` (L39)
- func `get_count` (L47)
- func `get_row_by_id` (L51)
- func `rows_where` (L58)
- func `next_id` (L66)
- func `add_row` (L86)
- func `update_row` (L106)
- func `delete_row` (L126)
- func `delete_rows_where` (L137)
- func `config_get` (L154)
- func `config_set` (L161)
- func `add_scene` (L174)
- func `get_all_scene` (L177)
- func `get_scene` (L180)
- func `update_scene` (L183)
- func `del_scene` (L187)
- func `add_map` (L207)
- func `get_map` (L210)
- func `get_all_map` (L213)
- func `delete_map` (L216)
- func `link_scene` (L223)
- func `reverse_direction` (L231)
- func `del_link_path` (L243)
- func `update_link_path` (L246)
- func `get_link_path` (L249)
- func `get_all_link_path` (L252)
- func `add_object` (L257)
- func `get_all_object` (L260)
- func `get_object` (L263)
- func `update_object` (L266)
- func `delete_object` (L269)
- func `add_object_to_scene` (L279)
- func `del_object_from_scene` (L283)
- func `get_objects_by_scene` (L296)
- func `update_object_in_scene` (L299)
- func `module_talk_add` (L304)
- func `module_talk_delete` (L307)
- func `module_talk_query` (L310)
- func `module_talk_query_with_objid` (L313)
- func `module_talk_update` (L316)
- func `add_property` (L321)
- func `get_property` (L324)
- func `get_property_by_name` (L328)
- func `delete_property` (L334)
- func `update_property` (L337)
- func `add_property_type` (L340)
- func `get_property_type` (L343)
- func `delete_property_type` (L346)
- func `add_item` (L351)
- func `get_item` (L354)
- func `delete_item` (L359)
- func `update_item` (L362)
- func `add_item_type` (L365)
- func `get_item_type` (L368)
- func `delete_item_type` (L373)
- func `add_skill` (L378)
- func `get_skill` (L381)
- func `delete_skill` (L386)
- func `add_skill_type` (L389)
- func `get_skill_type` (L392)
- func `delete_skill_type` (L397)
- func `add_alternation` (L402)
- func `get_alternation` (L403)
- func `delete_alternation` (L404)
- func `add_reward` (L406)
- func `get_reward` (L407)
- func `delete_reward` (L408)
- func `add_story` (L410)
- func `get_story` (L411)
- func `delete_story` (L412)
- func `add_enemy` (L414)
- func `get_enemy` (L415)
- func `delete_enemy` (L416)
- func `add_enemy_template` (L418)
- func `get_enemy_template` (L419)
- func `delete_enemy_template` (L420)
- func `add_campaign` (L422)
- func `get_campaign` (L423)
- func `delete_campaign` (L424)
- func `add_slot` (L426)
- func `get_slot` (L427)
- func `delete_slot` (L428)
- func `add_slot_template` (L430)
- func `get_slot_template` (L431)
- func `delete_slot_template` (L432)
- func `add_random` (L434)
- func `get_random` (L435)
- func `delete_random` (L436)
- func `add_trade` (L438)
- func `get_trade` (L439)
- func `delete_trade` (L440)
- func `add_generator` (L442)
- func `get_generator` (L443)
- func `delete_generator` (L444)
- func `add_payment` (L446)
- func `get_payment` (L447)
- func `delete_payment` (L448)
- func `add_logic` (L450)
- func `get_logic` (L451)
- func `delete_logic` (L452)
- func `add_custom_data` (L454)
- func `get_custom_data` (L455)
- func `delete_custom_data` (L456)
- func `add_script_pluggin` (L458)
- func `get_script_pluggin` (L459)
- func `delete_script_pluggin` (L460)
- func `to_dict` (L471)
- func `from_dict` (L487)
- func `is_internal_format` (L513)

### scripts/editor/mud/mud_export.gd (`MudExport`)

- class_name **MudExport**
- func `lua_json_encode` (L26)
- func `parse_condition` (L133)
- func `get_result` (L162)
- func `get_result_data` (L173)
- func `generate_need_or_visible_data` (L188)
- func `generate_result_data` (L202)
- func `handle_effect` (L217)
- func `get_property_dependent` (L242)
- func `generate_random_event_data` (L275)
- func `generate_exchange_data` (L299)
- func `generate_result` (L335)
- func `load_city_objects` (L344)
- func `load_citys` (L360)
- func `load_city_ways` (L380)
- func `load_goods_action` (L401)
- func `load_goods` (L420)
- func `load_property` (L428)
- func `load_property_tag_name` (L507)
- func `load_goods_tag_name` (L517)
- func `load_goods_use` (L527)
- func `load_question` (L596)
- func `load_story` (L634)
- func `load_drop` (L659)
- func `load_npc` (L686)
- func `load_npc_combat` (L718)
- func `load_skill` (L768)
- func `load_skill_tag_name` (L808)
- func `load_slot` (L818)
- func `load_combat_property` (L828)
- func `load_map_enter` (L843)
- func `load_random_action` (L849)
- func `load_navigation` (L869)
- func `load_exchange` (L877)
- func `load_object_auto_run` (L899)
- func `load_pay` (L935)
- func `load_online_func` (L951)
- func `load_share_prize` (L955)
- func `load_common_action` (L962)
- func `load_game_info` (L983)
- func `load_setting` (L987)
- func `load_custom_data` (L1008)
- func `load_lua_export` (L1021)
- func `export_all` (L1034)
- func `write_all` (L1080)

### scripts/editor/mud/mud_import.gd (`MudImport`)

- class_name **MudImport**
- func `get_data` (L23)
- func `from_dir` (L29)
- func `from_dict` (L35)
- func `is_export_format` (L41)

### scripts/editor/mud/mud_map_canvas.gd (`MudMapCanvas`)

- class_name **MudMapCanvas**
- signal `scene_selected`
- signal `scene_activated`
- signal `empty_cell_clicked`
- signal `scene_move_requested`
- signal `scene_swap_requested`
- signal `link_target_chosen`
- signal `node_context_requested`
- signal `blank_context_requested`
- signal `hint_message`
- func `_ready` (L66)
- func `set_data` (L72)
- func `set_map` (L81)
- func `get_selected_id` (L88)
- func `set_selected` (L91)
- func `enter_link_mode` (L96)
- func `cancel_link_mode` (L108)
- func `is_link_mode` (L117)

### scripts/editor/mud/mud_schema_internal.gd (`MudSchemaInternal`)

- class_name **MudSchemaInternal**
- func `has_table` (L472)
- func `get_table` (L476)
- func `get_display_name` (L482)
- func `get_field_names` (L491)
- func `get_field` (L501)
- func `get_field_type` (L515)
- func `get_field_default` (L524)
- func `create_default_entry` (L535)
- func `is_editor_only` (L543)
- func `get_unique_indexes` (L547)
- func `find_unique_conflict` (L554)

### scripts/editor/mud/mud_table_widget.gd (`MudTableWidget`)

- class_name **MudTableWidget**
- signal `row_selected`
- signal `row_activated`
- func `_ready` (L258)
- func `setup` (L262)
- func `get_columns_config` (L296)
- func `refresh` (L328)
- func `set_filter` (L362)
- func `get_selected_id` (L513)
- func `select_by_id` (L516)

### scripts/editor/mud/mud_trigger_editor.gd (`MudTriggerEditor`)

- class_name **MudTriggerEditor**
- signal `changed`
- func `set_type_label` (L67)
- func `set_data_source` (L73)
- func `set_block` (L86)
- func `get_block` (L96)
- func `set_config` (L111)
- func `get_config` (L117)
- func `fill_subtype_options` (L272)

## scripts/editor/mud/dialogs/

### scripts/editor/mud/dialogs/mud_code_theme.gd (`MudCodeTheme`)

- class_name **MudCodeTheme**
- func `make_lua_highlighter` (L60)
- func `make_json_highlighter` (L86)
- func `make_highlighter` (L98)
- func `apply_to` (L107)
- func `make_code_edit` (L119)
- func `get_templates` (L240)
- func `make_template_button` (L255)

### scripts/editor/mud/dialogs/mud_edit_dialog_base.gd (`MudEditDialogBase`)

- class_name **MudEditDialogBase**
- signal `saved`
- func `open_dialog` (L65)
- func `add_header` (L105)
- func `clear_header` (L119)
- func `field_line` (L139)
- func `field_int` (L147)
- func `field_text` (L157)
- func `field_check` (L166)
- func `field_select` (L176)
- func `make_select` (L187)
- func `make_label` (L195)
- func `make_comment` (L202)
- func `make_tabs` (L212)
- func `make_tab_page` (L219)
- func `make_trigger` (L228)
- func `load_trigger` (L274)
- func `collect_trigger` (L285)

### scripts/editor/mud/dialogs/mud_edit_generic.gd (`MudEditGeneric`)

- class_name **MudEditGeneric**

### scripts/editor/mud/dialogs/mud_edit_item.gd (`MudEditItem`)

- class_name **MudEditItem**

### scripts/editor/mud/dialogs/mud_edit_path.gd (`MudEditPath`)

- class_name **MudEditPath**

### scripts/editor/mud/dialogs/mud_edit_property.gd (`MudEditProperty`)

- class_name **MudEditProperty**

### scripts/editor/mud/dialogs/mud_edit_scene.gd (`MudEditScene`)

- class_name **MudEditScene**

### scripts/editor/mud/dialogs/mud_edit_scene_object.gd (`MudEditSceneObject`)

- class_name **MudEditSceneObject**
- func `open_for_scene` (L14)

### scripts/editor/mud/dialogs/mud_edit_skill.gd (`MudEditSkill`)

- class_name **MudEditSkill**

### scripts/editor/mud/dialogs/mud_edit_talk.gd (`MudEditTalk`)

- class_name **MudEditTalk**

### scripts/editor/mud/dialogs/mud_global_config.gd (`MudGlobalConfig`)

- class_name **MudGlobalConfig**
- func `open_config` (L45)

### scripts/editor/mud/dialogs/mud_scene_object_panel.gd (`MudSceneObjectPanel`)

- class_name **MudSceneObjectPanel**
- func `setup` (L22)
- func `refresh` (L67)
- func `save_current` (L112)

## scripts/editor/mud/tabs/

### scripts/editor/mud/tabs/mud_tab_builder.gd (`MudTabBuilder`)

- class_name **MudTabBuilder**
- signal `status_message`
- signal `advanced_edit_requested`
- signal `csv_export_requested`
- signal `csv_import_requested`
- func `set_data` (L38)
- func `get_tab_container` (L45)
- func `get_selected_id` (L48)
- func `build` (L53)
- func `refresh_all` (L488)
- func `refresh_table` (L495)

### scripts/editor/mud/tabs/mud_tab_configs.gd (`MudTabConfigs`)

- class_name **MudTabConfigs**

## scripts/editor/panels/

### scripts/editor/panels/ability_panel.gd (ability_panel.gd)

- func `load_data` (L38)
- func `get_data` (L279)

### scripts/editor/panels/economy_panel.gd (economy_panel.gd)

- func `load_data` (L35)
- func `get_data` (L250)

### scripts/editor/panels/event_panel.gd (event_panel.gd)

- func `_ready` (L18)
- func `get_data` (L137)

### scripts/editor/panels/worldview_panel.gd (worldview_panel.gd)

- func `_ready` (L18)
- func `get_data` (L111)

## scripts/editor/visual/

### scripts/editor/visual/visual_ability.gd (visual_ability.gd)

- func `get_nav_title` (L4)
- func `get_nav_items` (L7)
- func `create` (L17)

### scripts/editor/visual/visual_ai_assistant.gd (visual_ai_assistant.gd)

- func `create` (L20)

### scripts/editor/visual/visual_blueprint_draw.gd (`VisualBlueprintDraw`)

- class_name **VisualBlueprintDraw**
- func `screen_to_world` (L28)
- func `world_to_screen` (L32)
- func `draw_grid` (L36)
- func `draw_bp_node` (L65)
- func `draw_bp_pins` (L95)
- func `draw_connection` (L107)
- func `cubic_bezier` (L118)
- func `get_pin_world_pos` (L127)
- func `hit_test_node` (L135)
- func `hit_test_pins` (L148)
- func `draw_blueprint_node` (L164)
- func `draw_typed_pins` (L236)
- func `draw_exec_connection` (L289)
- func `hit_test_bp_pins` (L318)
- func `hit_test_bp_node` (L338)

### scripts/editor/visual/visual_blueprint_workspace.gd (visual_blueprint_workspace.gd)

- func `create` (L25)

### scripts/editor/visual/visual_combat.gd (visual_combat.gd)

- func `get_nav_title` (L4)
- func `get_nav_items` (L7)
- func `create` (L15)

### scripts/editor/visual/visual_economy.gd (visual_economy.gd)

- func `get_nav_title` (L4)
- func `get_nav_items` (L7)
- func `create` (L17)

### scripts/editor/visual/visual_event.gd (visual_event.gd)

- func `create` (L15)

### scripts/editor/visual/visual_event_blueprint.gd (`VisualEventBlueprint`)

- class_name **VisualEventBlueprint**

### scripts/editor/visual/visual_event_l1_form.gd (`VisualEventL1Form`)

- class_name **VisualEventL1Form**
- func `undo_form` (L43)
- func `redo_form` (L52)
- func `can_undo_form` (L79)
- func `can_redo_form` (L82)

### scripts/editor/visual/visual_map.gd (visual_map.gd)

- func `create` (L5)

### scripts/editor/visual/visual_module_base.gd (`VisualModuleBase`)

- class_name **VisualModuleBase**
- func `build_standard_layout` (L45)
- func `get_nav_title` (L107)
- func `get_nav_items` (L111)

### scripts/editor/visual/visual_quest.gd (visual_quest.gd)

- func `get_nav_title` (L4)
- func `get_nav_items` (L7)
- func `create` (L14)

### scripts/editor/visual/visual_system_blueprint.gd (visual_system_blueprint.gd)

- func `create` (L41)

### scripts/editor/visual/visual_test_runner.gd (visual_test_runner.gd)

- func `create` (L5)

### scripts/editor/visual/visual_worldview.gd (visual_worldview.gd)

- func `get_nav_title` (L4)
- func `get_nav_items` (L7)
- func `create` (L20)

## scripts/player/

### scripts/player/blueprint_executor.gd (`BlueprintExecutor`)

- class_name **BlueprintExecutor**
- signal `log_message`
- signal `execution_finished`
- func `init_engines` (L36)
- func `execute_graph` (L45)
- func `execute_from` (L49)
- func `resume_choice` (L93)
- func `execute_sub_graph` (L107)
- func `halt` (L123)

### scripts/player/blueprint_node_handlers.gd (`BlueprintNodeHandlers`)

- class_name **BlueprintNodeHandlers**
- func `dispatch` (L17)
- func `run` (L37)
- func `handle_flow` (L54)
- func `handle_economy` (L129)
- func `handle_story` (L241)
- func `handle_world` (L358)
- func `handle_player` (L438)
- func `handle_combat` (L516)
- func `handle_ability` (L655)
- func `handle_quest` (L732)

### scripts/player/combat_engine.gd (combat_engine.gd)

- signal `combat_started`
- signal `combat_round_started`
- signal `action_taken`
- signal `combat_ended`
- func `reset_battle` (L16)
- func `init` (L30)
- func `set_player_stats` (L34)
- func `add_enemy` (L54)
- func `start_combat` (L86)
- func `player_attack` (L105)
- func `player_use_skill` (L137)
- func `try_flee` (L237)
- func `get_log` (L354)
- func `get_rewards` (L358)

### scripts/player/economy_engine.gd (economy_engine.gd)

- func `init` (L16)
- func `load_from_dict` (L32)
- func `to_dict` (L37)
- func `get_price` (L41)
- func `set_price` (L47)
- func `buy` (L53)
- func `sell` (L68)
- func `update_market_prices` (L81)
- func `add_currency` (L97)
- func `add_item` (L101)
- func `remove_item` (L105)

### scripts/player/event_engine.gd (event_engine.gd)

- signal `event_triggered`
- signal `choices_presented`
- signal `choice_made`
- func `init` (L35)
- func `load_history` (L41)
- func `to_dict` (L49)
- func `check_triggerable_events` (L58)
- func `trigger_event` (L72)
- func `mark_triggered` (L87)
- func `make_choice` (L97)
- func `tick_cooldowns` (L271)
- func `check_random_events` (L281)

### scripts/player/graph_store.gd (`GraphStore`)

- class_name **GraphStore**
- func `event_key` (L13)
- func `system_key` (L17)
- func `is_event_key` (L21)
- func `event_id_from_key` (L25)
- func `get_graph` (L29)
- func `set_graph` (L35)
- func `has_graph` (L41)
- func `remove_graph` (L45)
- func `list_graphs` (L50)
- func `list_system_keys` (L59)

### scripts/player/script_player.gd (script_player.gd)

- func `_ready` (L95)
- func `settings_auto_save_interval_min` (L185)
- func `_process` (L193)

### scripts/player/world_state.gd (world_state.gd)

- func `load_from_dict` (L17)
- func `to_dict` (L26)
- func `advance_time` (L36)
- func `set_variable` (L52)
- func `get_variable` (L56)
- func `initialize_factions` (L60)
- func `modify_faction_relationship` (L83)
- func `get_faction_relationship` (L92)
- func `add_effect` (L98)
- func `tick_effects` (L102)
- func `get_time_display` (L113)
- func `get_current_day` (L119)
- func `get_current_hour` (L123)
- func `get_period_name` (L127)

## scripts/ui/

### scripts/ui/confirm_dialog.gd (confirm_dialog.gd)

- signal `confirmed`
- signal `cancelled`
- func `show_dialog` (L13)

### scripts/ui/main_hub.gd (main_hub.gd)

- func `_ready` (L64)

### scripts/ui/script_setup_dialog.gd (`ScriptSetupDialog`)

- class_name **ScriptSetupDialog**
- signal `setup_completed`
- signal `cancelled`
- func `_ready` (L26)
- func `show_dialog` (L188)

### scripts/ui/settings.gd (settings.gd)

- func `_ready` (L26)

### scripts/ui/template_dialog.gd (template_dialog.gd)

- signal `template_selected`
- signal `cancelled`
- func `_ready` (L14)
- func `show_dialog` (L23)

### scripts/ui/toast_manager.gd (toast_manager.gd)

- func `_ready` (L16)
- func `info` (L31)
- func `success` (L35)
- func `warning` (L39)
- func `error` (L43)

## scripts/ui/components/

### scripts/ui/components/empty_state.gd (`EmptyState`)

- class_name **EmptyState**
- signal `action_pressed`
- func `_ready` (L36)
- func `setup` (L44)

### scripts/ui/components/modal_overlay.gd (`ModalOverlay`)

- class_name **ModalOverlay**
- signal `opened`
- signal `closed`
- func `_ready` (L17)
- func `open` (L22)
- func `close` (L42)

### scripts/ui/components/recent_card.gd (`RecentCard`)

- class_name **RecentCard**
- signal `clicked`
- func `setup` (L13)
- func `_ready` (L19)

### scripts/ui/components/script_card.gd (`ScriptCard`)

- class_name **ScriptCard**
- signal `clicked`
- signal `double_clicked`
- signal `favorite_requested`
- signal `edit_requested`
- signal `delete_requested`
- func `setup` (L30)
- func `_ready` (L85)

### scripts/ui/components/section_header.gd (`SectionHeader`)

- class_name **SectionHeader**
- signal `action_pressed`
- func `_ready` (L36)

### scripts/ui/components/toast_item.gd (`ToastItem`)

- class_name **ToastItem**
- signal `finished`
- func `setup` (L54)
- func `_ready` (L64)
- func `_process` (L75)

## test/

### test/blueprint_runtime_test.gd (blueprint_runtime_test.gd)

- func `test_blueprint_event_full_chain` (L19)
- func `test_traditional_event_fallback` (L75)
- func `test_prerequisite_chain` (L88)

### test/smoke_test.gd (smoke_test.gd)

- func `test_addition` (L4)
- func `test_script_data_available` (L7)
- func `test_bool_logic` (L12)

## tools/

### tools/ui_layout_check.gd (ui_layout_check.gd)

- func `_initialize` (L28)

### tools/ui_motion_capture.gd (ui_motion_capture.gd)

- func `_initialize` (L12)

### tools/ui_screenshot.gd (ui_screenshot.gd)

- func `_initialize` (L9)

### tools/ui_walkthrough.gd (ui_walkthrough.gd)

- func `_initialize` (L12)

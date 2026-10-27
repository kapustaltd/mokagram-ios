# Desktop feature inventory

Desktop revision: `bb203b658dcdc5870dcee843ff77f99bc33a5dd9`. This index covers source files present in the local checkout, including uncommitted changes in its submodules; it is an inventory, not a claim of parity.

## Modules

### appearance
- `Telegram/SourceFiles/mokagram/appearance/mokagram_appearance.cpp`
- `Telegram/SourceFiles/mokagram/appearance/mokagram_appearance.h`

### avatar
- `Telegram/SourceFiles/mokagram/avatar/mokagram_avatar_shape.cpp`
- `Telegram/SourceFiles/mokagram/avatar/mokagram_avatar_shape.h`

### commands
- `Telegram/SourceFiles/mokagram/commands/mokagram_commands.cpp`
- `Telegram/SourceFiles/mokagram/commands/mokagram_commands.h`

### effects
- `Telegram/SourceFiles/mokagram/effects/mokagram_effects.cpp`
- `Telegram/SourceFiles/mokagram/effects/mokagram_effects.h`

### ghost
- `Telegram/SourceFiles/mokagram/ghost/mokagram_ghost.cpp`
- `Telegram/SourceFiles/mokagram/ghost/mokagram_ghost.h`

### history
- `Telegram/SourceFiles/mokagram/history/mokagram_history.cpp`
- `Telegram/SourceFiles/mokagram/history/mokagram_history.h`
- `Telegram/SourceFiles/mokagram/history/mokagram_history_filters.cpp`
- `Telegram/SourceFiles/mokagram/history/mokagram_history_filters.h`
- `Telegram/SourceFiles/mokagram/history/mokagram_history_store.cpp`
- `Telegram/SourceFiles/mokagram/history/mokagram_history_store.h`
- `Telegram/SourceFiles/mokagram/history/mokagram_history_ui.cpp`

### lang
- `Telegram/SourceFiles/mokagram/lang/mokagram_lang.cpp`
- `Telegram/SourceFiles/mokagram/lang/mokagram_lang.h`

### misc
- `Telegram/SourceFiles/mokagram/misc/mokagram_datereg.cpp`
- `Telegram/SourceFiles/mokagram/misc/mokagram_datereg.h`
- `Telegram/SourceFiles/mokagram/misc/mokagram_misc.cpp`
- `Telegram/SourceFiles/mokagram/misc/mokagram_misc.h`
- `Telegram/SourceFiles/mokagram/misc/mokagram_ping.cpp`
- `Telegram/SourceFiles/mokagram/misc/mokagram_ping.h`

### msginfo
- `Telegram/SourceFiles/mokagram/msginfo/mokagram_message_info.cpp`
- `Telegram/SourceFiles/mokagram/msginfo/mokagram_message_info.h`

### music
- `Telegram/SourceFiles/mokagram/music/mokagram_lyrics.cpp`
- `Telegram/SourceFiles/mokagram/music/mokagram_lyrics.h`
- `Telegram/SourceFiles/mokagram/music/mokagram_music_library.cpp`
- `Telegram/SourceFiles/mokagram/music/mokagram_music_library.h`
- `Telegram/SourceFiles/mokagram/music/mokagram_music_ui.cpp`
- `Telegram/SourceFiles/mokagram/music/mokagram_music_ui.h`
- `Telegram/SourceFiles/mokagram/music/mokagram_soundcloud.cpp`
- `Telegram/SourceFiles/mokagram/music/mokagram_soundcloud.h`

### notes
- `Telegram/SourceFiles/mokagram/notes/mokagram_notes.cpp`
- `Telegram/SourceFiles/mokagram/notes/mokagram_notes.h`

### perf
- `Telegram/SourceFiles/mokagram/perf/mokagram_perf.cpp`
- `Telegram/SourceFiles/mokagram/perf/mokagram_perf.h`

### plugins
- `Telegram/SourceFiles/mokagram/plugins/mokagram_plugin_api.cpp`
- `Telegram/SourceFiles/mokagram/plugins/mokagram_plugin_api.h`
- `Telegram/SourceFiles/mokagram/plugins/mokagram_plugin_install.cpp`
- `Telegram/SourceFiles/mokagram/plugins/mokagram_plugin_install.h`
- `Telegram/SourceFiles/mokagram/plugins/mokagram_plugin_store.cpp`
- `Telegram/SourceFiles/mokagram/plugins/mokagram_plugin_store.h`
- `Telegram/SourceFiles/mokagram/plugins/mokagram_plugins.cpp`
- `Telegram/SourceFiles/mokagram/plugins/mokagram_plugins.h`
- `Telegram/SourceFiles/mokagram/plugins/py/base_plugin.py`
- `Telegram/SourceFiles/mokagram/plugins/py/fw.py`
- `Telegram/SourceFiles/mokagram/plugins/py/gen_tl.py`
- `Telegram/SourceFiles/mokagram/plugins/py/gen_tl_schema.py`
- `Telegram/SourceFiles/mokagram/plugins/py/host.py`
- `Telegram/SourceFiles/mokagram/plugins/py/sdk_api.py`
- `Telegram/SourceFiles/mokagram/plugins/py/tl.py`
- `Telegram/SourceFiles/mokagram/plugins/py/tl_names.py`

### quote
- `Telegram/SourceFiles/mokagram/quote/mokagram_quote.cpp`
- `Telegram/SourceFiles/mokagram/quote/mokagram_quote.h`

### saveinator
- `Telegram/SourceFiles/mokagram/saveinator/mokagram_saveinator.cpp`
- `Telegram/SourceFiles/mokagram/saveinator/mokagram_saveinator.h`

### scam
- `Telegram/SourceFiles/mokagram/scam/mokagram_scam.cpp`
- `Telegram/SourceFiles/mokagram/scam/mokagram_scam.h`

### settings
- `Telegram/SourceFiles/mokagram/settings/mokagram_settings.cpp`
- `Telegram/SourceFiles/mokagram/settings/mokagram_settings.h`
- `Telegram/SourceFiles/mokagram/settings/mokagram_settings_box.cpp`
- `Telegram/SourceFiles/mokagram/settings/mokagram_settings_box.h`

### snippets
- `Telegram/SourceFiles/mokagram/snippets/mokagram_snippets.cpp`
- `Telegram/SourceFiles/mokagram/snippets/mokagram_snippets.h`

### stars
- `Telegram/SourceFiles/mokagram/stars/mokagram_stars_stats.cpp`
- `Telegram/SourceFiles/mokagram/stars/mokagram_stars_stats.h`

### streamer
- `Telegram/SourceFiles/mokagram/streamer/mokagram_streamer.cpp`
- `Telegram/SourceFiles/mokagram/streamer/mokagram_streamer.h`

### ui
- `Telegram/SourceFiles/mokagram/ui/mokagram_box_parts.cpp`
- `Telegram/SourceFiles/mokagram/ui/mokagram_box_parts.h`
- `Telegram/SourceFiles/mokagram/ui/mokagram_glass.h`
- `Telegram/SourceFiles/mokagram/ui/mokagram_report_box.cpp`
- `Telegram/SourceFiles/mokagram/ui/mokagram_report_box.h`

### update
- `Telegram/SourceFiles/mokagram/update/mokagram_update.cpp`
- `Telegram/SourceFiles/mokagram/update/mokagram_update.h`

## Integration points

Files outside the module directory containing `Mokagram::` references or `Mokagram:` markers. Review each for behavior and unmarked changes when reconciling the port.

| File | Referenced namespaces | Markers |
| --- | --- | ---: |
| `api/api_send_progress.cpp` | Ghost | 1 |
| `api/api_updates.cpp` | Ghost, Plugins | 4 |
| `apiwrap.cpp` | Ghost, Plugins, Snippets | 5 |
| `boxes/about_box.cpp` | — | 1 |
| `boxes/delete_messages_box.cpp` | BoxParts | 10 |
| `boxes/edit_privacy_box.cpp` | Streamer | 4 |
| `boxes/filters/edit_filter_box.cpp` | — | 1 |
| `boxes/gift_premium_box.cpp` | — | 1 |
| `boxes/peer_list_box.h` | — | 2 |
| `boxes/peers/add_participants_box.cpp` | — | 1 |
| `boxes/peers/edit_peer_invite_link.cpp` | Streamer | 8 |
| `boxes/peers/edit_peer_usernames_list.cpp` | Streamer | 4 |
| `boxes/report_messages_box.cpp` | Report | 1 |
| `boxes/send_files_box.cpp` | BoxParts | 16 |
| `boxes/star_gift_cover_box.cpp` | — | 1 |
| `boxes/sticker_set_box.cpp` | Lang, Misc | 3 |
| `chat_helpers/chat_helpers.style` | — | 2 |
| `chat_helpers/tabbed_selector.cpp` | — | 4 |
| `core/application.cpp` | Appearance, Avatar, Badges, Commands, Effects, Ghost, Guard, History, Misc, Perf, Plugins, Quote, Saveinator, Scam, Settings, Streamer, Update | 28 |
| `core/click_handler_types.cpp` | Scam | 1 |
| `core/local_url_handlers.cpp` | Streamer | 20 |
| `data/data_document_resolver.cpp` | Plugins | 2 |
| `data/data_file_click_handler.cpp` | Plugins | 2 |
| `data/data_histories.cpp` | Ghost | 3 |
| `data/data_media_types.cpp` | History | 4 |
| `data/data_message_reactions.cpp` | — | 1 |
| `data/data_peer.cpp` | Avatar | 2 |
| `data/data_replies_list.cpp` | Ghost | 1 |
| `data/data_send_action.cpp` | Plugins | 1 |
| `data/data_session.cpp` | Badges, History | 6 |
| `data/data_stories.cpp` | Ghost | 4 |
| `data/data_user.cpp` | Badges | 8 |
| `data/stickers/data_custom_emoji.cpp` | — | 3 |
| `dialogs/dialogs_inner_widget.cpp` | History, Streamer | 8 |
| `dialogs/dialogs_inner_widget.h` | — | 1 |
| `dialogs/dialogs_widget.cpp` | Lang | 2 |
| `dialogs/ui/dialogs_layout.cpp` | Notes | 4 |
| `editor/video/video_editor_layer.cpp` | — | 1 |
| `history/history_inner_widget.cpp` | Appearance, Effects, History, Lang, MessageInfo, Misc, Quote, Saveinator, Streamer | 28 |
| `history/history_item.cpp` | Ghost, History, Plugins, Scam | 10 |
| `history/history_item_components.cpp` | Scam | 3 |
| `history/history_item_helpers.cpp` | — | 1 |
| `history/history_widget.cpp` | Commands, History, Plugins, Saveinator | 8 |
| `history/history_widget.h` | — | 1 |
| `history/view/history_view_bottom_info.cpp` | History, Plugins, Settings | 3 |
| `history/view/history_view_chat_section.cpp` | Saveinator | 1 |
| `history/view/history_view_context_menu.cpp` | History, Lang, Misc, Plugins, Saveinator | 7 |
| `history/view/history_view_element.cpp` | History | 1 |
| `history/view/history_view_list_widget.cpp` | Appearance, Ghost, Settings | 6 |
| `history/view/history_view_message.cpp` | Badges, History, Scam | 11 |
| `history/view/history_view_top_bar_widget.cpp` | Notes, Plugins | 5 |
| `history/view/history_view_translate_bar.cpp` | — | 1 |
| `history/view/history_view_translate_bar.h` | — | 1 |
| `history/view/media/history_view_gif.cpp` | Settings | 2 |
| `history/view/media/history_view_sticker.cpp` | Settings | 1 |
| `info/info_content_widget.cpp` | — | 1 |
| `info/info_layer_widget.cpp` | — | 4 |
| `info/info_top_bar.cpp` | — | 4 |
| `info/info_wrap_widget.cpp` | — | 2 |
| `info/peer_gifts/info_peer_gifts_widget.cpp` | — | 1 |
| `info/profile/info_profile_actions.cpp` | Lang, Misc, Notes, Streamer | 55 |
| `info/profile/info_profile_music_button.cpp` | — | 1 |
| `info/profile/info_profile_music_button.h` | — | 1 |
| `info/profile/info_profile_section_stack.cpp` | — | 6 |
| `info/profile/info_profile_top_bar.cpp` | — | 7 |
| `info/profile/info_profile_values.cpp` | Badges, Streamer | 30 |
| `info/profile/tabs/info_profile_tabs_strip.cpp` | — | 1 |
| `info/stories/info_stories_inner_widget.cpp` | — | 1 |
| `inline_bots/bot_attach_web_view.cpp` | Plugins | 1 |
| `inline_bots/inline_bot_layout_internal.cpp` | — | 1 |
| `inline_bots/inline_results_inner.cpp` | — | 1 |
| `lang/lang_instance.cpp` | Misc | 2 |
| `main/main_domain.cpp` | Settings | 4 |
| `main/main_domain.h` | — | 1 |
| `media/player/media_player_dropdown.cpp` | — | 1 |
| `media/player/media_player_instance.cpp` | Music, Settings | 10 |
| `media/player/media_player_widget.cpp` | Music | 15 |
| `menu/menu_mark_as_read.cpp` | Ghost | 2 |
| `mtproto/mtp_instance.cpp` | Plugins | 10 |
| `settings/sections/settings_information.cpp` | Plugins, Streamer | 9 |
| `settings/sections/settings_main.cpp` | Lang, Plugins, Settings | 26 |
| `settings/sections/settings_notifications.cpp` | — | 1 |
| `settings/settings_builder.cpp` | Plugins | 6 |
| `settings/settings_builder.h` | — | 1 |
| `settings/settings_common.cpp` | Settings | 10 |
| `settings/settings_credits_graphics.cpp` | Plugins | 8 |
| `settings/settings_power_saving.cpp` | Plugins | 1 |
| `ui/chat/pinned_bar.cpp` | — | 1 |
| `ui/countryinput.cpp` | — | 1 |
| `ui/userpic_view.cpp` | Avatar | 4 |
| `ui/vertical_list.cpp` | — | 1 |
| `ui/widgets/discrete_sliders.cpp` | — | 4 |
| `window/notifications_manager.cpp` | Streamer | 6 |
| `window/window_main_menu.cpp` | Music, Plugins, Streamer | 14 |
| `window/window_peer_menu.cpp` | BoxParts, Ghost, Guard, History, Lang, Plugins | 28 |
| `window/window_session_controller.cpp` | Plugins | 3 |

## Not applicable on iOS (decided 2026-10-27; see design.md section 5)

The Python plugin host IS ported, with Desktop compatibility (design.md 4.10): distribution is ad-hoc with a paid developer account, not the App Store.

| Desktop feature | Reason |
| --- | --- |
| Autostart and close-to-tray ("Launch and background" settings) | No such concepts on iOS; background work follows iOS rules. |
| Rounded window shadows, profile window background and corner radii (`1a5d5c3704`, `8a0cb3e8e9`) | Desktop window chrome. |
| `lib_ui.patch`, `lib_webview.patch` | Qt-library patches. |
| Ed25519-signed self-update (`update/`) | The App Store / TestFlight / IPA channel replaces it; only the signature scheme may be reused for plugin or settings packages. |

## Gaps closed by section 8 of tasks.md

Settings registry, badges, Guard and threat exemptions, ping, misc utilities, localization fallback, first-run window, dialog additions, music extras, report box, small chat UI changes and power-saving integration.

-- ============================================================================
-- 单位数据库：七个兵种表（我方步兵 / 重甲 / 支援 / 战场雇佣 + 敌方步兵 / 重甲 / 支援）
--
-- 字段设计来源：RTS.xlsx（A 列字段名 / B 列类型 / C 列说明 / D~G 列出兵单位 id 约定）
--   unit_id(infantry / heavy_tank / medic / inf_temp) / cost / build_time / max_hp / armor /
--   move_speed / action_range / action_value / action_cd / target_type
-- 在此基础上按需求补充：armor_penetration（破甲值）
-- 以及代码内使用的静态数值列（编队、碰撞体、红区净空、回血、自爆、冲锋、动画、敌方 AI），
-- 字段名与类型可自行调整，方便后续继续设计数值。
--
-- 七张表结构完全一致（列定义相同），只是数据不同，便于横向对比与 UNION 查询。
-- 对某一方不适用的列留 NULL（例如敌方没有回血与队员隔离，我方没有追踪 AI）。
--
-- 尺寸标定基准：现役单位的人物显示尺寸统一标定为 50×50 像素，
--   因此身体相关的像素列（character_scale / collision_radius / member_collision_radius /
--   formation_side / red_zone_clearance / member_separation / 移动与归队速度 /
--   bar_width / shadow_offset_y / ring_* / 敌方隔离与巡逻参数等）都按同一比例
--   1.875 标定（旧值以 26 像素高的人物为基准 → ×1.875 后显示高度落在 49~53 像素），
--   我方渲染缩放 = 0.30 × 1.875 = 0.5625，敌方 = 0.145 × 1.875 = 0.272。
--   射程（action_range / track_range）、自爆半径（detonate_radius）与击退距离
--   （knockback_distance）是需求里明确指定的绝对值，不随人物尺寸缩放，保持原值。
--
-- 本文件是单位数值的唯一真源：WG.html 不再内联任何单位数值，页面启动时直接读取
--   build_unit_db.py 从本文件生成的 unit_db.js（window.UNIT_DB）。
--   改数值流程：编辑本文件 -> 运行 `python build_unit_db.py` -> 刷新页面。
-- 填写约定：现役单位（如下表 player_infantry.JF / enemy_infantry.Vespid）必须填满所有列；
--   其他兵种的数值若尚未设计，可以只填 unit_id 与已知字段，其余列直接省略（视同未填）。
-- 语法：通用 SQL（SQLite / MySQL 均可直接执行），可重复执行（每次先删表再建表）。
-- ============================================================================

DROP TABLE IF EXISTS player_infantry;
CREATE TABLE player_infantry (  -- infantry（现役单位 JF）
  unit_id                        VARCHAR(32) NOT NULL PRIMARY KEY,  -- 单位唯一标识
  unit_name                      VARCHAR(32) DEFAULT NULL,  -- 显示名
  cost                           INT NOT NULL DEFAULT 0,  -- 招募消耗：出兵时从可用点数中一次性扣除的点数
  build_time                     FLOAT NOT NULL DEFAULT 0,  -- 训练耗时（秒）
  max_hp                         INT NOT NULL DEFAULT 1,  -- 最大生命值
  armor                          INT NOT NULL DEFAULT 0,  -- 固定减伤护甲
  move_speed                     FLOAT NOT NULL DEFAULT 0,  -- 移动速度（像素/秒）
  action_range                   FLOAT NOT NULL DEFAULT 0,  -- 攻击/作用距离（像素）
  action_value                   INT NOT NULL DEFAULT 0,  -- 作用数值（正为伤害/治疗）
  action_cd                      FLOAT NOT NULL DEFAULT 0,  -- 技能冷却/攻击间隔（秒）
  target_type                    INT NOT NULL DEFAULT 0 CHECK (target_type IN (0, 1)),  -- 作用目标判定：0 = 敌方单位，1 = 我方单位（支援单位对我方回血用）
  armor_penetration              INT NOT NULL DEFAULT 0,  -- 破甲值：对拥有护甲的敌人能减去的护甲值
  -- ---- 以下为代码内使用的静态数值（自定字段名与类型）----
  squad_size                     INT DEFAULT 1,  -- 编队人数：多人独立碰撞体、合并为一个基本单位
  roster                         VARCHAR(128) DEFAULT NULL,  -- 编队花名册（逗号分隔；最后一项为队长）
  character_scale                FLOAT DEFAULT NULL,  -- 角色渲染缩放
  collision_radius               FLOAT DEFAULT NULL,  -- 单位移动碰撞体半径
  member_collision_radius        FLOAT DEFAULT NULL,  -- 单名队员的圆形判定体半径
  formation_side                 FLOAT DEFAULT NULL,  -- 三角阵型边长
  red_zone_clearance             FLOAT DEFAULT NULL,  -- 与红色屏蔽区边缘保持的安全距离
  member_separation              FLOAT DEFAULT NULL,  -- 队员之间的最小间距
  member_enemy_separation        FLOAT DEFAULT NULL,  -- 队员与敌方单位之间的隔离距离
  regen_delay                    INT DEFAULT NULL,  -- 距上次受击多久开始回血（毫秒）
  regen_per_second               FLOAT DEFAULT NULL,  -- 每秒恢复的最大生命值比例
  detonate_delay                 INT DEFAULT NULL,  -- 血条耗尽到自爆/引爆的延迟（毫秒）
  detonate_radius                FLOAT DEFAULT NULL,  -- 自爆半径（像素）
  detonate_damage                FLOAT DEFAULT NULL,  -- 爆心伤害
  detonate_damage_falloff        FLOAT DEFAULT NULL,  -- 每档伤害递减比例
  detonate_falloff_step          FLOAT DEFAULT NULL,  -- 伤害递减档距（像素）
  charge_speed                   FLOAT DEFAULT NULL,  -- 阵亡冲锋速度（像素/秒）
  charge_trigger_distance        FLOAT DEFAULT NULL,  -- 贴上该距离立即自爆（像素）
  death_tint_duration            INT DEFAULT NULL,  -- 阵亡泛红时长（毫秒）
  death_tint_strength            FLOAT DEFAULT NULL,  -- 阵亡泛红强度
  track_range                    FLOAT DEFAULT NULL,  -- 追踪范围（敌方 AI，像素）
  attack_release_margin          FLOAT DEFAULT NULL,  -- 停火迟滞带（像素）
  track_release_margin           FLOAT DEFAULT NULL,  -- 放弃追踪迟滞带（像素）
  -- ---- 部署扣点（经济）----
  deploy_cost                    INT DEFAULT NULL,  -- 驻场削点：场上每存在一个该兵种，每分钟可获得的点数上限减少该值（不直接扣当前点数）
  -- ---- 队员隔离与归队（我方）----
  member_separation_max_push     FLOAT DEFAULT NULL,  -- 队员隔离每帧最大推挤位移（像素）
  member_anim_max_step           FLOAT DEFAULT NULL,  -- 队员渲染位置每帧最大位移（像素）
  member_return_distance         FLOAT DEFAULT NULL,  -- 掉队判定距离（像素）
  member_return_exit_ratio       FLOAT DEFAULT NULL,  -- 归队迟滞比例：收进「判定距离 × 该比例」以内才算归位
  member_return_extra_clearance  FLOAT DEFAULT NULL,  -- 归位通道净空额外量（像素），最终净空 = red_zone_clearance + 该值
  member_return_speed            FLOAT DEFAULT NULL,  -- 归队移动速度（像素/秒）
  member_return_replan_distance  FLOAT DEFAULT NULL,  -- 归队路径的重新规划距离阈值（像素）
  member_return_waypoint_radius  FLOAT DEFAULT NULL,  -- 归队路径拐点的到达判定距离（像素）
  -- ---- 阵型与收拢（我方）----
  squad_regroup_arrive           FLOAT DEFAULT NULL,  -- 归位判定距离（像素）
  squad_regroup_catchup_distance FLOAT DEFAULT NULL,  -- 落后该距离后开始提速归队（像素）
  squad_regroup_stall_ratio      FLOAT DEFAULT NULL,  -- 单帧靠近量不足预算的该比例即累计卡滞
  squad_regroup_stall_frames     INT DEFAULT NULL,  -- 连续卡滞帧数达到该值即视为已归位
  squad_free_return_ratio        FLOAT DEFAULT NULL,  -- 超出自由散开范围后的回收速度倍率（相对行军速度）
  squad_separation_target        FLOAT DEFAULT NULL,  -- 队形被挤压时的兜底隔离距离（像素）
  squad_separation_buffer        FLOAT DEFAULT NULL,  -- 队形隔离的收敛容差
  squad_order_spread             FLOAT DEFAULT NULL,  -- 多队同时移动时终点圆环分摊半径（像素）：越小越贴近点击点，取值需保证相邻小队贴近而不相叠
  squad_separation_passes        INT DEFAULT NULL,  -- 队员隔离与红区净空交替求解轮数
  squad_edge_range               FLOAT DEFAULT NULL,  -- 判定「已贴到红色屏蔽区边缘」的额外距离（像素）
  squad_edge_exit_range          FLOAT DEFAULT NULL,  -- 贴红区判定的退出迟滞距离（像素）
  squad_formation_lerp           FLOAT DEFAULT NULL,  -- 行进方向插值系数（避免拐角处方向跳变）
  squad_morph_duration           INT DEFAULT NULL,  -- 三角阵型与自由散开的过渡时长（毫秒）
  squad_free_spread              FLOAT DEFAULT NULL,  -- 自由移动时的横向展开量（像素）
  squad_free_max_distance        FLOAT DEFAULT NULL,  -- 队员与队形中心的最大距离（像素）
  squad_free_back_left           FLOAT DEFAULT NULL,  -- 自由站位「左侧」沿行进方向的落后量（像素）
  squad_free_back_apex           FLOAT DEFAULT NULL,  -- 自由站位「中间」沿行进方向的落后量（像素，负为更靠前）
  squad_free_back_right          FLOAT DEFAULT NULL,  -- 自由站位「右侧」沿行进方向的落后量（像素）
  squad_slot_swap_blend          FLOAT DEFAULT NULL,  -- 允许重新分配站位所需的散开完成度
  -- ---- 动画（我方）----
  animation_mix_attack           FLOAT DEFAULT NULL,  -- 攻击与移动/待机交叉淡化时长（秒）
  animation_mix_loop             FLOAT DEFAULT NULL,  -- 移动与待机交叉淡化时长（秒）
  attack_animation_fallback      INT DEFAULT NULL,  -- 取不到攻击动画时长时的兜底锁定时长（毫秒）
  animation_lock_grace           FLOAT DEFAULT NULL,  -- 一次性动画尾帧保留容差（毫秒）
  spawn_animation_duration       INT DEFAULT NULL,  -- 出生动画时长（毫秒）
  spawn_animation_min_scale      FLOAT DEFAULT NULL,  -- 出生动画起始缩放（相对正常体型）
  -- ---- 红区绕行与移动容错（我方）----
  red_route_range                FLOAT DEFAULT NULL,  -- 「移动路线范围内」的红区判定半径（像素）
  red_steer_bias                 FLOAT DEFAULT NULL,  -- 沿红色屏蔽区行走时的额外外扩量（保证净空足额）
  move_stall_timeout             INT DEFAULT NULL,  -- 贴着红区打转、长时间无法靠近终点的判定时长（毫秒）
  move_progress_epsilon          FLOAT DEFAULT NULL,  -- 判定「确实靠近了终点」的最小距离（像素）
  charge_retarget_interval       INT DEFAULT NULL,  -- 阵亡冲锋的重新索敌间隔（毫秒）
  -- ---- 视觉尺寸 ----
  bar_width                      FLOAT DEFAULT NULL,  -- 血条宽度（像素）
  shadow_width_ratio             FLOAT DEFAULT NULL,  -- 脚下阴影宽度 / 单位显示宽度
  shadow_flatten                 FLOAT DEFAULT NULL,  -- 脚下阴影高度 / 宽度
  shadow_alpha                   FLOAT DEFAULT NULL,  -- 脚下阴影透明度
  shadow_offset_y                FLOAT DEFAULT NULL,  -- 脚下阴影相对单位原点的纵向偏移（像素）
  ring_width                     FLOAT DEFAULT NULL,  -- 脚下选中圆环宽度（像素）
  ring_height                    FLOAT DEFAULT NULL,  -- 脚下选中圆环高度（像素）
  ring_offset_y                  FLOAT DEFAULT NULL,  -- 脚下选中圆环纵向偏移（像素）
  -- ---- 敌方 AI 与行动路线 ----
  hold_duration                  INT DEFAULT NULL,  -- 行动点待机时长（毫秒）
  patrol_radius                  FLOAT DEFAULT NULL,  -- 待机巡逻范围半径（像素）
  patrol_min_radius              FLOAT DEFAULT NULL,  -- 巡逻折返的最小半径（像素）
  patrol_slack                   FLOAT DEFAULT NULL,  -- 巡逻硬约束容差（像素）
  endpoint_roam_radius           FLOAT DEFAULT NULL,  -- 路线终点自由待机区域半径（像素）
  endpoint_idle_min              INT DEFAULT NULL,  -- 终点到位后随机静止时长下限（毫秒）
  endpoint_idle_max              INT DEFAULT NULL,  -- 终点到位后随机静止时长上限（毫秒）
  endpoint_return_slack_factor   FLOAT DEFAULT NULL,  -- 终点回位距离 = 待机半径 + patrol_slack × 该系数
  route_corridor                 FLOAT DEFAULT NULL,  -- 移动路线走廊半宽（像素）
  route_variant_count            INT DEFAULT NULL,  -- 每条主路线生成的随机变体数量
  spawn_offmap_padding           FLOAT DEFAULT NULL,  -- 出生点在地图外额外补足的入场距离（像素）
  separation_strength            FLOAT DEFAULT NULL,  -- 单位隔离每帧推开重叠量的比例
  separation_max_push            FLOAT DEFAULT NULL,  -- 单位隔离每帧最大推挤位移（像素）
  replan_cooldown                INT DEFAULT NULL,  -- 路径重规划冷却（毫秒）
  stuck_time                     INT DEFAULT NULL,  -- 卡滞判定时长（毫秒）
  stuck_distance                 FLOAT DEFAULT NULL,  -- 卡滞判定位移阈值（像素）
  attack_contact_tolerance       FLOAT DEFAULT NULL,  -- 进入攻击范围的到位容差（像素）
  attack_animation_loop          INT DEFAULT NULL,  -- 攻击姿态是否循环播放（1 = 循环）
  knockback_distance             FLOAT DEFAULT NULL,  -- 被击中后的击退距离（像素）
  knockback_duration             INT DEFAULT NULL  -- 被击中后的击退持续时间（毫秒）
);

DROP TABLE IF EXISTS player_heavy;
CREATE TABLE player_heavy (  -- heavy_tank
  unit_id                        VARCHAR(32) NOT NULL PRIMARY KEY,  -- 单位唯一标识
  unit_name                      VARCHAR(32) DEFAULT NULL,  -- 显示名
  cost                           INT NOT NULL DEFAULT 0,  -- 招募消耗：出兵时从可用点数中一次性扣除的点数
  build_time                     FLOAT NOT NULL DEFAULT 0,  -- 训练耗时（秒）
  max_hp                         INT NOT NULL DEFAULT 1,  -- 最大生命值
  armor                          INT NOT NULL DEFAULT 0,  -- 固定减伤护甲
  move_speed                     FLOAT NOT NULL DEFAULT 0,  -- 移动速度（像素/秒）
  action_range                   FLOAT NOT NULL DEFAULT 0,  -- 攻击/作用距离（像素）
  action_value                   INT NOT NULL DEFAULT 0,  -- 作用数值（正为伤害/治疗）
  action_cd                      FLOAT NOT NULL DEFAULT 0,  -- 技能冷却/攻击间隔（秒）
  target_type                    INT NOT NULL DEFAULT 0 CHECK (target_type IN (0, 1)),  -- 作用目标判定：0 = 敌方单位，1 = 我方单位（支援单位对我方回血用）
  armor_penetration              INT NOT NULL DEFAULT 0,  -- 破甲值：对拥有护甲的敌人能减去的护甲值
  -- ---- 以下为代码内使用的静态数值（自定字段名与类型）----
  squad_size                     INT DEFAULT 1,  -- 编队人数：多人独立碰撞体、合并为一个基本单位
  roster                         VARCHAR(128) DEFAULT NULL,  -- 编队花名册（逗号分隔；最后一项为队长）
  character_scale                FLOAT DEFAULT NULL,  -- 角色渲染缩放
  collision_radius               FLOAT DEFAULT NULL,  -- 单位移动碰撞体半径
  member_collision_radius        FLOAT DEFAULT NULL,  -- 单名队员的圆形判定体半径
  formation_side                 FLOAT DEFAULT NULL,  -- 三角阵型边长
  red_zone_clearance             FLOAT DEFAULT NULL,  -- 与红色屏蔽区边缘保持的安全距离
  member_separation              FLOAT DEFAULT NULL,  -- 队员之间的最小间距
  member_enemy_separation        FLOAT DEFAULT NULL,  -- 队员与敌方单位之间的隔离距离
  regen_delay                    INT DEFAULT NULL,  -- 距上次受击多久开始回血（毫秒）
  regen_per_second               FLOAT DEFAULT NULL,  -- 每秒恢复的最大生命值比例
  detonate_delay                 INT DEFAULT NULL,  -- 血条耗尽到自爆/引爆的延迟（毫秒）
  detonate_radius                FLOAT DEFAULT NULL,  -- 自爆半径（像素）
  detonate_damage                FLOAT DEFAULT NULL,  -- 爆心伤害
  detonate_damage_falloff        FLOAT DEFAULT NULL,  -- 每档伤害递减比例
  detonate_falloff_step          FLOAT DEFAULT NULL,  -- 伤害递减档距（像素）
  charge_speed                   FLOAT DEFAULT NULL,  -- 阵亡冲锋速度（像素/秒）
  charge_trigger_distance        FLOAT DEFAULT NULL,  -- 贴上该距离立即自爆（像素）
  death_tint_duration            INT DEFAULT NULL,  -- 阵亡泛红时长（毫秒）
  death_tint_strength            FLOAT DEFAULT NULL,  -- 阵亡泛红强度
  track_range                    FLOAT DEFAULT NULL,  -- 追踪范围（敌方 AI，像素）
  attack_release_margin          FLOAT DEFAULT NULL,  -- 停火迟滞带（像素）
  track_release_margin           FLOAT DEFAULT NULL,  -- 放弃追踪迟滞带（像素）
  -- ---- 部署扣点（经济）----
  deploy_cost                    INT DEFAULT NULL,  -- 驻场削点：场上每存在一个该兵种，每分钟可获得的点数上限减少该值（不直接扣当前点数）
  -- ---- 队员隔离与归队（我方）----
  member_separation_max_push     FLOAT DEFAULT NULL,  -- 队员隔离每帧最大推挤位移（像素）
  member_anim_max_step           FLOAT DEFAULT NULL,  -- 队员渲染位置每帧最大位移（像素）
  member_return_distance         FLOAT DEFAULT NULL,  -- 掉队判定距离（像素）
  member_return_exit_ratio       FLOAT DEFAULT NULL,  -- 归队迟滞比例：收进「判定距离 × 该比例」以内才算归位
  member_return_extra_clearance  FLOAT DEFAULT NULL,  -- 归位通道净空额外量（像素），最终净空 = red_zone_clearance + 该值
  member_return_speed            FLOAT DEFAULT NULL,  -- 归队移动速度（像素/秒）
  member_return_replan_distance  FLOAT DEFAULT NULL,  -- 归队路径的重新规划距离阈值（像素）
  member_return_waypoint_radius  FLOAT DEFAULT NULL,  -- 归队路径拐点的到达判定距离（像素）
  -- ---- 阵型与收拢（我方）----
  squad_regroup_arrive           FLOAT DEFAULT NULL,  -- 归位判定距离（像素）
  squad_regroup_catchup_distance FLOAT DEFAULT NULL,  -- 落后该距离后开始提速归队（像素）
  squad_regroup_stall_ratio      FLOAT DEFAULT NULL,  -- 单帧靠近量不足预算的该比例即累计卡滞
  squad_regroup_stall_frames     INT DEFAULT NULL,  -- 连续卡滞帧数达到该值即视为已归位
  squad_free_return_ratio        FLOAT DEFAULT NULL,  -- 超出自由散开范围后的回收速度倍率（相对行军速度）
  squad_separation_target        FLOAT DEFAULT NULL,  -- 队形被挤压时的兜底隔离距离（像素）
  squad_separation_buffer        FLOAT DEFAULT NULL,  -- 队形隔离的收敛容差
  squad_order_spread             FLOAT DEFAULT NULL,  -- 多队同时移动时终点圆环分摊半径（像素）：越小越贴近点击点，取值需保证相邻小队贴近而不相叠
  squad_separation_passes        INT DEFAULT NULL,  -- 队员隔离与红区净空交替求解轮数
  squad_edge_range               FLOAT DEFAULT NULL,  -- 判定「已贴到红色屏蔽区边缘」的额外距离（像素）
  squad_edge_exit_range          FLOAT DEFAULT NULL,  -- 贴红区判定的退出迟滞距离（像素）
  squad_formation_lerp           FLOAT DEFAULT NULL,  -- 行进方向插值系数（避免拐角处方向跳变）
  squad_morph_duration           INT DEFAULT NULL,  -- 三角阵型与自由散开的过渡时长（毫秒）
  squad_free_spread              FLOAT DEFAULT NULL,  -- 自由移动时的横向展开量（像素）
  squad_free_max_distance        FLOAT DEFAULT NULL,  -- 队员与队形中心的最大距离（像素）
  squad_free_back_left           FLOAT DEFAULT NULL,  -- 自由站位「左侧」沿行进方向的落后量（像素）
  squad_free_back_apex           FLOAT DEFAULT NULL,  -- 自由站位「中间」沿行进方向的落后量（像素，负为更靠前）
  squad_free_back_right          FLOAT DEFAULT NULL,  -- 自由站位「右侧」沿行进方向的落后量（像素）
  squad_slot_swap_blend          FLOAT DEFAULT NULL,  -- 允许重新分配站位所需的散开完成度
  -- ---- 动画（我方）----
  animation_mix_attack           FLOAT DEFAULT NULL,  -- 攻击与移动/待机交叉淡化时长（秒）
  animation_mix_loop             FLOAT DEFAULT NULL,  -- 移动与待机交叉淡化时长（秒）
  attack_animation_fallback      INT DEFAULT NULL,  -- 取不到攻击动画时长时的兜底锁定时长（毫秒）
  animation_lock_grace           FLOAT DEFAULT NULL,  -- 一次性动画尾帧保留容差（毫秒）
  spawn_animation_duration       INT DEFAULT NULL,  -- 出生动画时长（毫秒）
  spawn_animation_min_scale      FLOAT DEFAULT NULL,  -- 出生动画起始缩放（相对正常体型）
  -- ---- 红区绕行与移动容错（我方）----
  red_route_range                FLOAT DEFAULT NULL,  -- 「移动路线范围内」的红区判定半径（像素）
  red_steer_bias                 FLOAT DEFAULT NULL,  -- 沿红色屏蔽区行走时的额外外扩量（保证净空足额）
  move_stall_timeout             INT DEFAULT NULL,  -- 贴着红区打转、长时间无法靠近终点的判定时长（毫秒）
  move_progress_epsilon          FLOAT DEFAULT NULL,  -- 判定「确实靠近了终点」的最小距离（像素）
  charge_retarget_interval       INT DEFAULT NULL,  -- 阵亡冲锋的重新索敌间隔（毫秒）
  -- ---- 视觉尺寸 ----
  bar_width                      FLOAT DEFAULT NULL,  -- 血条宽度（像素）
  shadow_width_ratio             FLOAT DEFAULT NULL,  -- 脚下阴影宽度 / 单位显示宽度
  shadow_flatten                 FLOAT DEFAULT NULL,  -- 脚下阴影高度 / 宽度
  shadow_alpha                   FLOAT DEFAULT NULL,  -- 脚下阴影透明度
  shadow_offset_y                FLOAT DEFAULT NULL,  -- 脚下阴影相对单位原点的纵向偏移（像素）
  ring_width                     FLOAT DEFAULT NULL,  -- 脚下选中圆环宽度（像素）
  ring_height                    FLOAT DEFAULT NULL,  -- 脚下选中圆环高度（像素）
  ring_offset_y                  FLOAT DEFAULT NULL,  -- 脚下选中圆环纵向偏移（像素）
  -- ---- 敌方 AI 与行动路线 ----
  hold_duration                  INT DEFAULT NULL,  -- 行动点待机时长（毫秒）
  patrol_radius                  FLOAT DEFAULT NULL,  -- 待机巡逻范围半径（像素）
  patrol_min_radius              FLOAT DEFAULT NULL,  -- 巡逻折返的最小半径（像素）
  patrol_slack                   FLOAT DEFAULT NULL,  -- 巡逻硬约束容差（像素）
  endpoint_roam_radius           FLOAT DEFAULT NULL,  -- 路线终点自由待机区域半径（像素）
  endpoint_idle_min              INT DEFAULT NULL,  -- 终点到位后随机静止时长下限（毫秒）
  endpoint_idle_max              INT DEFAULT NULL,  -- 终点到位后随机静止时长上限（毫秒）
  endpoint_return_slack_factor   FLOAT DEFAULT NULL,  -- 终点回位距离 = 待机半径 + patrol_slack × 该系数
  route_corridor                 FLOAT DEFAULT NULL,  -- 移动路线走廊半宽（像素）
  route_variant_count            INT DEFAULT NULL,  -- 每条主路线生成的随机变体数量
  spawn_offmap_padding           FLOAT DEFAULT NULL,  -- 出生点在地图外额外补足的入场距离（像素）
  separation_strength            FLOAT DEFAULT NULL,  -- 单位隔离每帧推开重叠量的比例
  separation_max_push            FLOAT DEFAULT NULL,  -- 单位隔离每帧最大推挤位移（像素）
  replan_cooldown                INT DEFAULT NULL,  -- 路径重规划冷却（毫秒）
  stuck_time                     INT DEFAULT NULL,  -- 卡滞判定时长（毫秒）
  stuck_distance                 FLOAT DEFAULT NULL,  -- 卡滞判定位移阈值（像素）
  attack_contact_tolerance       FLOAT DEFAULT NULL,  -- 进入攻击范围的到位容差（像素）
  attack_animation_loop          INT DEFAULT NULL,  -- 攻击姿态是否循环播放（1 = 循环）
  knockback_distance             FLOAT DEFAULT NULL,  -- 被击中后的击退距离（像素）
  knockback_duration             INT DEFAULT NULL  -- 被击中后的击退持续时间（毫秒）
);

DROP TABLE IF EXISTS player_support;
CREATE TABLE player_support (  -- medic（target_type = 1 为我方单位回血）
  unit_id                        VARCHAR(32) NOT NULL PRIMARY KEY,  -- 单位唯一标识
  unit_name                      VARCHAR(32) DEFAULT NULL,  -- 显示名
  cost                           INT NOT NULL DEFAULT 0,  -- 招募消耗：出兵时从可用点数中一次性扣除的点数
  build_time                     FLOAT NOT NULL DEFAULT 0,  -- 训练耗时（秒）
  max_hp                         INT NOT NULL DEFAULT 1,  -- 最大生命值
  armor                          INT NOT NULL DEFAULT 0,  -- 固定减伤护甲
  move_speed                     FLOAT NOT NULL DEFAULT 0,  -- 移动速度（像素/秒）
  action_range                   FLOAT NOT NULL DEFAULT 0,  -- 攻击/作用距离（像素）
  action_value                   INT NOT NULL DEFAULT 0,  -- 作用数值（正为伤害/治疗）
  action_cd                      FLOAT NOT NULL DEFAULT 0,  -- 技能冷却/攻击间隔（秒）
  target_type                    INT NOT NULL DEFAULT 0 CHECK (target_type IN (0, 1)),  -- 作用目标判定：0 = 敌方单位，1 = 我方单位（支援单位对我方回血用）
  armor_penetration              INT NOT NULL DEFAULT 0,  -- 破甲值：对拥有护甲的敌人能减去的护甲值
  -- ---- 以下为代码内使用的静态数值（自定字段名与类型）----
  squad_size                     INT DEFAULT 1,  -- 编队人数：多人独立碰撞体、合并为一个基本单位
  roster                         VARCHAR(128) DEFAULT NULL,  -- 编队花名册（逗号分隔；最后一项为队长）
  character_scale                FLOAT DEFAULT NULL,  -- 角色渲染缩放
  collision_radius               FLOAT DEFAULT NULL,  -- 单位移动碰撞体半径
  member_collision_radius        FLOAT DEFAULT NULL,  -- 单名队员的圆形判定体半径
  formation_side                 FLOAT DEFAULT NULL,  -- 三角阵型边长
  red_zone_clearance             FLOAT DEFAULT NULL,  -- 与红色屏蔽区边缘保持的安全距离
  member_separation              FLOAT DEFAULT NULL,  -- 队员之间的最小间距
  member_enemy_separation        FLOAT DEFAULT NULL,  -- 队员与敌方单位之间的隔离距离
  regen_delay                    INT DEFAULT NULL,  -- 距上次受击多久开始回血（毫秒）
  regen_per_second               FLOAT DEFAULT NULL,  -- 每秒恢复的最大生命值比例
  detonate_delay                 INT DEFAULT NULL,  -- 血条耗尽到自爆/引爆的延迟（毫秒）
  detonate_radius                FLOAT DEFAULT NULL,  -- 自爆半径（像素）
  detonate_damage                FLOAT DEFAULT NULL,  -- 爆心伤害
  detonate_damage_falloff        FLOAT DEFAULT NULL,  -- 每档伤害递减比例
  detonate_falloff_step          FLOAT DEFAULT NULL,  -- 伤害递减档距（像素）
  charge_speed                   FLOAT DEFAULT NULL,  -- 阵亡冲锋速度（像素/秒）
  charge_trigger_distance        FLOAT DEFAULT NULL,  -- 贴上该距离立即自爆（像素）
  death_tint_duration            INT DEFAULT NULL,  -- 阵亡泛红时长（毫秒）
  death_tint_strength            FLOAT DEFAULT NULL,  -- 阵亡泛红强度
  track_range                    FLOAT DEFAULT NULL,  -- 追踪范围（敌方 AI，像素）
  attack_release_margin          FLOAT DEFAULT NULL,  -- 停火迟滞带（像素）
  track_release_margin           FLOAT DEFAULT NULL,  -- 放弃追踪迟滞带（像素）
  -- ---- 部署扣点（经济）----
  deploy_cost                    INT DEFAULT NULL,  -- 驻场削点：场上每存在一个该兵种，每分钟可获得的点数上限减少该值（不直接扣当前点数）
  -- ---- 队员隔离与归队（我方）----
  member_separation_max_push     FLOAT DEFAULT NULL,  -- 队员隔离每帧最大推挤位移（像素）
  member_anim_max_step           FLOAT DEFAULT NULL,  -- 队员渲染位置每帧最大位移（像素）
  member_return_distance         FLOAT DEFAULT NULL,  -- 掉队判定距离（像素）
  member_return_exit_ratio       FLOAT DEFAULT NULL,  -- 归队迟滞比例：收进「判定距离 × 该比例」以内才算归位
  member_return_extra_clearance  FLOAT DEFAULT NULL,  -- 归位通道净空额外量（像素），最终净空 = red_zone_clearance + 该值
  member_return_speed            FLOAT DEFAULT NULL,  -- 归队移动速度（像素/秒）
  member_return_replan_distance  FLOAT DEFAULT NULL,  -- 归队路径的重新规划距离阈值（像素）
  member_return_waypoint_radius  FLOAT DEFAULT NULL,  -- 归队路径拐点的到达判定距离（像素）
  -- ---- 阵型与收拢（我方）----
  squad_regroup_arrive           FLOAT DEFAULT NULL,  -- 归位判定距离（像素）
  squad_regroup_catchup_distance FLOAT DEFAULT NULL,  -- 落后该距离后开始提速归队（像素）
  squad_regroup_stall_ratio      FLOAT DEFAULT NULL,  -- 单帧靠近量不足预算的该比例即累计卡滞
  squad_regroup_stall_frames     INT DEFAULT NULL,  -- 连续卡滞帧数达到该值即视为已归位
  squad_free_return_ratio        FLOAT DEFAULT NULL,  -- 超出自由散开范围后的回收速度倍率（相对行军速度）
  squad_separation_target        FLOAT DEFAULT NULL,  -- 队形被挤压时的兜底隔离距离（像素）
  squad_separation_buffer        FLOAT DEFAULT NULL,  -- 队形隔离的收敛容差
  squad_order_spread             FLOAT DEFAULT NULL,  -- 多队同时移动时终点圆环分摊半径（像素）：越小越贴近点击点，取值需保证相邻小队贴近而不相叠
  squad_separation_passes        INT DEFAULT NULL,  -- 队员隔离与红区净空交替求解轮数
  squad_edge_range               FLOAT DEFAULT NULL,  -- 判定「已贴到红色屏蔽区边缘」的额外距离（像素）
  squad_edge_exit_range          FLOAT DEFAULT NULL,  -- 贴红区判定的退出迟滞距离（像素）
  squad_formation_lerp           FLOAT DEFAULT NULL,  -- 行进方向插值系数（避免拐角处方向跳变）
  squad_morph_duration           INT DEFAULT NULL,  -- 三角阵型与自由散开的过渡时长（毫秒）
  squad_free_spread              FLOAT DEFAULT NULL,  -- 自由移动时的横向展开量（像素）
  squad_free_max_distance        FLOAT DEFAULT NULL,  -- 队员与队形中心的最大距离（像素）
  squad_free_back_left           FLOAT DEFAULT NULL,  -- 自由站位「左侧」沿行进方向的落后量（像素）
  squad_free_back_apex           FLOAT DEFAULT NULL,  -- 自由站位「中间」沿行进方向的落后量（像素，负为更靠前）
  squad_free_back_right          FLOAT DEFAULT NULL,  -- 自由站位「右侧」沿行进方向的落后量（像素）
  squad_slot_swap_blend          FLOAT DEFAULT NULL,  -- 允许重新分配站位所需的散开完成度
  -- ---- 动画（我方）----
  animation_mix_attack           FLOAT DEFAULT NULL,  -- 攻击与移动/待机交叉淡化时长（秒）
  animation_mix_loop             FLOAT DEFAULT NULL,  -- 移动与待机交叉淡化时长（秒）
  attack_animation_fallback      INT DEFAULT NULL,  -- 取不到攻击动画时长时的兜底锁定时长（毫秒）
  animation_lock_grace           FLOAT DEFAULT NULL,  -- 一次性动画尾帧保留容差（毫秒）
  spawn_animation_duration       INT DEFAULT NULL,  -- 出生动画时长（毫秒）
  spawn_animation_min_scale      FLOAT DEFAULT NULL,  -- 出生动画起始缩放（相对正常体型）
  -- ---- 红区绕行与移动容错（我方）----
  red_route_range                FLOAT DEFAULT NULL,  -- 「移动路线范围内」的红区判定半径（像素）
  red_steer_bias                 FLOAT DEFAULT NULL,  -- 沿红色屏蔽区行走时的额外外扩量（保证净空足额）
  move_stall_timeout             INT DEFAULT NULL,  -- 贴着红区打转、长时间无法靠近终点的判定时长（毫秒）
  move_progress_epsilon          FLOAT DEFAULT NULL,  -- 判定「确实靠近了终点」的最小距离（像素）
  charge_retarget_interval       INT DEFAULT NULL,  -- 阵亡冲锋的重新索敌间隔（毫秒）
  -- ---- 视觉尺寸 ----
  bar_width                      FLOAT DEFAULT NULL,  -- 血条宽度（像素）
  shadow_width_ratio             FLOAT DEFAULT NULL,  -- 脚下阴影宽度 / 单位显示宽度
  shadow_flatten                 FLOAT DEFAULT NULL,  -- 脚下阴影高度 / 宽度
  shadow_alpha                   FLOAT DEFAULT NULL,  -- 脚下阴影透明度
  shadow_offset_y                FLOAT DEFAULT NULL,  -- 脚下阴影相对单位原点的纵向偏移（像素）
  ring_width                     FLOAT DEFAULT NULL,  -- 脚下选中圆环宽度（像素）
  ring_height                    FLOAT DEFAULT NULL,  -- 脚下选中圆环高度（像素）
  ring_offset_y                  FLOAT DEFAULT NULL,  -- 脚下选中圆环纵向偏移（像素）
  -- ---- 敌方 AI 与行动路线 ----
  hold_duration                  INT DEFAULT NULL,  -- 行动点待机时长（毫秒）
  patrol_radius                  FLOAT DEFAULT NULL,  -- 待机巡逻范围半径（像素）
  patrol_min_radius              FLOAT DEFAULT NULL,  -- 巡逻折返的最小半径（像素）
  patrol_slack                   FLOAT DEFAULT NULL,  -- 巡逻硬约束容差（像素）
  endpoint_roam_radius           FLOAT DEFAULT NULL,  -- 路线终点自由待机区域半径（像素）
  endpoint_idle_min              INT DEFAULT NULL,  -- 终点到位后随机静止时长下限（毫秒）
  endpoint_idle_max              INT DEFAULT NULL,  -- 终点到位后随机静止时长上限（毫秒）
  endpoint_return_slack_factor   FLOAT DEFAULT NULL,  -- 终点回位距离 = 待机半径 + patrol_slack × 该系数
  route_corridor                 FLOAT DEFAULT NULL,  -- 移动路线走廊半宽（像素）
  route_variant_count            INT DEFAULT NULL,  -- 每条主路线生成的随机变体数量
  spawn_offmap_padding           FLOAT DEFAULT NULL,  -- 出生点在地图外额外补足的入场距离（像素）
  separation_strength            FLOAT DEFAULT NULL,  -- 单位隔离每帧推开重叠量的比例
  separation_max_push            FLOAT DEFAULT NULL,  -- 单位隔离每帧最大推挤位移（像素）
  replan_cooldown                INT DEFAULT NULL,  -- 路径重规划冷却（毫秒）
  stuck_time                     INT DEFAULT NULL,  -- 卡滞判定时长（毫秒）
  stuck_distance                 FLOAT DEFAULT NULL,  -- 卡滞判定位移阈值（像素）
  attack_contact_tolerance       FLOAT DEFAULT NULL,  -- 进入攻击范围的到位容差（像素）
  attack_animation_loop          INT DEFAULT NULL,  -- 攻击姿态是否循环播放（1 = 循环）
  knockback_distance             FLOAT DEFAULT NULL,  -- 被击中后的击退距离（像素）
  knockback_duration             INT DEFAULT NULL  -- 被击中后的击退持续时间（毫秒）
);

DROP TABLE IF EXISTS player_merc;
CREATE TABLE player_merc (  -- inf_temp（战场雇佣 / 战场支援单位）
  unit_id                        VARCHAR(32) NOT NULL PRIMARY KEY,  -- 单位唯一标识
  unit_name                      VARCHAR(32) DEFAULT NULL,  -- 显示名
  cost                           INT NOT NULL DEFAULT 0,  -- 招募消耗：出兵时从可用点数中一次性扣除的点数
  build_time                     FLOAT NOT NULL DEFAULT 0,  -- 训练耗时（秒）
  max_hp                         INT NOT NULL DEFAULT 1,  -- 最大生命值
  armor                          INT NOT NULL DEFAULT 0,  -- 固定减伤护甲
  move_speed                     FLOAT NOT NULL DEFAULT 0,  -- 移动速度（像素/秒）
  action_range                   FLOAT NOT NULL DEFAULT 0,  -- 攻击/作用距离（像素）
  action_value                   INT NOT NULL DEFAULT 0,  -- 作用数值（正为伤害/治疗）
  action_cd                      FLOAT NOT NULL DEFAULT 0,  -- 技能冷却/攻击间隔（秒）
  target_type                    INT NOT NULL DEFAULT 0 CHECK (target_type IN (0, 1)),  -- 作用目标判定：0 = 敌方单位，1 = 我方单位（支援单位对我方回血用）
  armor_penetration              INT NOT NULL DEFAULT 0,  -- 破甲值：对拥有护甲的敌人能减去的护甲值
  -- ---- 以下为代码内使用的静态数值（自定字段名与类型）----
  squad_size                     INT DEFAULT 1,  -- 编队人数：多人独立碰撞体、合并为一个基本单位
  roster                         VARCHAR(128) DEFAULT NULL,  -- 编队花名册（逗号分隔；最后一项为队长）
  character_scale                FLOAT DEFAULT NULL,  -- 角色渲染缩放
  collision_radius               FLOAT DEFAULT NULL,  -- 单位移动碰撞体半径
  member_collision_radius        FLOAT DEFAULT NULL,  -- 单名队员的圆形判定体半径
  formation_side                 FLOAT DEFAULT NULL,  -- 三角阵型边长
  red_zone_clearance             FLOAT DEFAULT NULL,  -- 与红色屏蔽区边缘保持的安全距离
  member_separation              FLOAT DEFAULT NULL,  -- 队员之间的最小间距
  member_enemy_separation        FLOAT DEFAULT NULL,  -- 队员与敌方单位之间的隔离距离
  regen_delay                    INT DEFAULT NULL,  -- 距上次受击多久开始回血（毫秒）
  regen_per_second               FLOAT DEFAULT NULL,  -- 每秒恢复的最大生命值比例
  detonate_delay                 INT DEFAULT NULL,  -- 血条耗尽到自爆/引爆的延迟（毫秒）
  detonate_radius                FLOAT DEFAULT NULL,  -- 自爆半径（像素）
  detonate_damage                FLOAT DEFAULT NULL,  -- 爆心伤害
  detonate_damage_falloff        FLOAT DEFAULT NULL,  -- 每档伤害递减比例
  detonate_falloff_step          FLOAT DEFAULT NULL,  -- 伤害递减档距（像素）
  charge_speed                   FLOAT DEFAULT NULL,  -- 阵亡冲锋速度（像素/秒）
  charge_trigger_distance        FLOAT DEFAULT NULL,  -- 贴上该距离立即自爆（像素）
  death_tint_duration            INT DEFAULT NULL,  -- 阵亡泛红时长（毫秒）
  death_tint_strength            FLOAT DEFAULT NULL,  -- 阵亡泛红强度
  track_range                    FLOAT DEFAULT NULL,  -- 追踪范围（敌方 AI，像素）
  attack_release_margin          FLOAT DEFAULT NULL,  -- 停火迟滞带（像素）
  track_release_margin           FLOAT DEFAULT NULL,  -- 放弃追踪迟滞带（像素）
  -- ---- 部署扣点（经济）----
  deploy_cost                    INT DEFAULT NULL,  -- 驻场削点：场上每存在一个该兵种，每分钟可获得的点数上限减少该值（不直接扣当前点数）
  -- ---- 队员隔离与归队（我方）----
  member_separation_max_push     FLOAT DEFAULT NULL,  -- 队员隔离每帧最大推挤位移（像素）
  member_anim_max_step           FLOAT DEFAULT NULL,  -- 队员渲染位置每帧最大位移（像素）
  member_return_distance         FLOAT DEFAULT NULL,  -- 掉队判定距离（像素）
  member_return_exit_ratio       FLOAT DEFAULT NULL,  -- 归队迟滞比例：收进「判定距离 × 该比例」以内才算归位
  member_return_extra_clearance  FLOAT DEFAULT NULL,  -- 归位通道净空额外量（像素），最终净空 = red_zone_clearance + 该值
  member_return_speed            FLOAT DEFAULT NULL,  -- 归队移动速度（像素/秒）
  member_return_replan_distance  FLOAT DEFAULT NULL,  -- 归队路径的重新规划距离阈值（像素）
  member_return_waypoint_radius  FLOAT DEFAULT NULL,  -- 归队路径拐点的到达判定距离（像素）
  -- ---- 阵型与收拢（我方）----
  squad_regroup_arrive           FLOAT DEFAULT NULL,  -- 归位判定距离（像素）
  squad_regroup_catchup_distance FLOAT DEFAULT NULL,  -- 落后该距离后开始提速归队（像素）
  squad_regroup_stall_ratio      FLOAT DEFAULT NULL,  -- 单帧靠近量不足预算的该比例即累计卡滞
  squad_regroup_stall_frames     INT DEFAULT NULL,  -- 连续卡滞帧数达到该值即视为已归位
  squad_free_return_ratio        FLOAT DEFAULT NULL,  -- 超出自由散开范围后的回收速度倍率（相对行军速度）
  squad_separation_target        FLOAT DEFAULT NULL,  -- 队形被挤压时的兜底隔离距离（像素）
  squad_separation_buffer        FLOAT DEFAULT NULL,  -- 队形隔离的收敛容差
  squad_order_spread             FLOAT DEFAULT NULL,  -- 多队同时移动时终点圆环分摊半径（像素）：越小越贴近点击点，取值需保证相邻小队贴近而不相叠
  squad_separation_passes        INT DEFAULT NULL,  -- 队员隔离与红区净空交替求解轮数
  squad_edge_range               FLOAT DEFAULT NULL,  -- 判定「已贴到红色屏蔽区边缘」的额外距离（像素）
  squad_edge_exit_range          FLOAT DEFAULT NULL,  -- 贴红区判定的退出迟滞距离（像素）
  squad_formation_lerp           FLOAT DEFAULT NULL,  -- 行进方向插值系数（避免拐角处方向跳变）
  squad_morph_duration           INT DEFAULT NULL,  -- 三角阵型与自由散开的过渡时长（毫秒）
  squad_free_spread              FLOAT DEFAULT NULL,  -- 自由移动时的横向展开量（像素）
  squad_free_max_distance        FLOAT DEFAULT NULL,  -- 队员与队形中心的最大距离（像素）
  squad_free_back_left           FLOAT DEFAULT NULL,  -- 自由站位「左侧」沿行进方向的落后量（像素）
  squad_free_back_apex           FLOAT DEFAULT NULL,  -- 自由站位「中间」沿行进方向的落后量（像素，负为更靠前）
  squad_free_back_right          FLOAT DEFAULT NULL,  -- 自由站位「右侧」沿行进方向的落后量（像素）
  squad_slot_swap_blend          FLOAT DEFAULT NULL,  -- 允许重新分配站位所需的散开完成度
  -- ---- 动画（我方）----
  animation_mix_attack           FLOAT DEFAULT NULL,  -- 攻击与移动/待机交叉淡化时长（秒）
  animation_mix_loop             FLOAT DEFAULT NULL,  -- 移动与待机交叉淡化时长（秒）
  attack_animation_fallback      INT DEFAULT NULL,  -- 取不到攻击动画时长时的兜底锁定时长（毫秒）
  animation_lock_grace           FLOAT DEFAULT NULL,  -- 一次性动画尾帧保留容差（毫秒）
  spawn_animation_duration       INT DEFAULT NULL,  -- 出生动画时长（毫秒）
  spawn_animation_min_scale      FLOAT DEFAULT NULL,  -- 出生动画起始缩放（相对正常体型）
  -- ---- 红区绕行与移动容错（我方）----
  red_route_range                FLOAT DEFAULT NULL,  -- 「移动路线范围内」的红区判定半径（像素）
  red_steer_bias                 FLOAT DEFAULT NULL,  -- 沿红色屏蔽区行走时的额外外扩量（保证净空足额）
  move_stall_timeout             INT DEFAULT NULL,  -- 贴着红区打转、长时间无法靠近终点的判定时长（毫秒）
  move_progress_epsilon          FLOAT DEFAULT NULL,  -- 判定「确实靠近了终点」的最小距离（像素）
  charge_retarget_interval       INT DEFAULT NULL,  -- 阵亡冲锋的重新索敌间隔（毫秒）
  -- ---- 视觉尺寸 ----
  bar_width                      FLOAT DEFAULT NULL,  -- 血条宽度（像素）
  shadow_width_ratio             FLOAT DEFAULT NULL,  -- 脚下阴影宽度 / 单位显示宽度
  shadow_flatten                 FLOAT DEFAULT NULL,  -- 脚下阴影高度 / 宽度
  shadow_alpha                   FLOAT DEFAULT NULL,  -- 脚下阴影透明度
  shadow_offset_y                FLOAT DEFAULT NULL,  -- 脚下阴影相对单位原点的纵向偏移（像素）
  ring_width                     FLOAT DEFAULT NULL,  -- 脚下选中圆环宽度（像素）
  ring_height                    FLOAT DEFAULT NULL,  -- 脚下选中圆环高度（像素）
  ring_offset_y                  FLOAT DEFAULT NULL,  -- 脚下选中圆环纵向偏移（像素）
  -- ---- 敌方 AI 与行动路线 ----
  hold_duration                  INT DEFAULT NULL,  -- 行动点待机时长（毫秒）
  patrol_radius                  FLOAT DEFAULT NULL,  -- 待机巡逻范围半径（像素）
  patrol_min_radius              FLOAT DEFAULT NULL,  -- 巡逻折返的最小半径（像素）
  patrol_slack                   FLOAT DEFAULT NULL,  -- 巡逻硬约束容差（像素）
  endpoint_roam_radius           FLOAT DEFAULT NULL,  -- 路线终点自由待机区域半径（像素）
  endpoint_idle_min              INT DEFAULT NULL,  -- 终点到位后随机静止时长下限（毫秒）
  endpoint_idle_max              INT DEFAULT NULL,  -- 终点到位后随机静止时长上限（毫秒）
  endpoint_return_slack_factor   FLOAT DEFAULT NULL,  -- 终点回位距离 = 待机半径 + patrol_slack × 该系数
  route_corridor                 FLOAT DEFAULT NULL,  -- 移动路线走廊半宽（像素）
  route_variant_count            INT DEFAULT NULL,  -- 每条主路线生成的随机变体数量
  spawn_offmap_padding           FLOAT DEFAULT NULL,  -- 出生点在地图外额外补足的入场距离（像素）
  separation_strength            FLOAT DEFAULT NULL,  -- 单位隔离每帧推开重叠量的比例
  separation_max_push            FLOAT DEFAULT NULL,  -- 单位隔离每帧最大推挤位移（像素）
  replan_cooldown                INT DEFAULT NULL,  -- 路径重规划冷却（毫秒）
  stuck_time                     INT DEFAULT NULL,  -- 卡滞判定时长（毫秒）
  stuck_distance                 FLOAT DEFAULT NULL,  -- 卡滞判定位移阈值（像素）
  attack_contact_tolerance       FLOAT DEFAULT NULL,  -- 进入攻击范围的到位容差（像素）
  attack_animation_loop          INT DEFAULT NULL,  -- 攻击姿态是否循环播放（1 = 循环）
  knockback_distance             FLOAT DEFAULT NULL,  -- 被击中后的击退距离（像素）
  knockback_duration             INT DEFAULT NULL  -- 被击中后的击退持续时间（毫秒）
);

DROP TABLE IF EXISTS enemy_infantry;
CREATE TABLE enemy_infantry (  -- Vespid（现役单位）
  unit_id                        VARCHAR(32) NOT NULL PRIMARY KEY,  -- 单位唯一标识
  unit_name                      VARCHAR(32) DEFAULT NULL,  -- 显示名
  cost                           INT NOT NULL DEFAULT 0,  -- 招募消耗：出兵时从可用点数中一次性扣除的点数
  build_time                     FLOAT NOT NULL DEFAULT 0,  -- 训练耗时（秒）
  max_hp                         INT NOT NULL DEFAULT 1,  -- 最大生命值
  armor                          INT NOT NULL DEFAULT 0,  -- 固定减伤护甲
  move_speed                     FLOAT NOT NULL DEFAULT 0,  -- 移动速度（像素/秒）
  action_range                   FLOAT NOT NULL DEFAULT 0,  -- 攻击/作用距离（像素）
  action_value                   INT NOT NULL DEFAULT 0,  -- 作用数值（正为伤害/治疗）
  action_cd                      FLOAT NOT NULL DEFAULT 0,  -- 技能冷却/攻击间隔（秒）
  target_type                    INT NOT NULL DEFAULT 0 CHECK (target_type IN (0, 1)),  -- 作用目标判定：0 = 敌方单位，1 = 我方单位（支援单位对我方回血用）
  armor_penetration              INT NOT NULL DEFAULT 0,  -- 破甲值：对拥有护甲的敌人能减去的护甲值
  -- ---- 以下为代码内使用的静态数值（自定字段名与类型）----
  squad_size                     INT DEFAULT 1,  -- 编队人数：多人独立碰撞体、合并为一个基本单位
  roster                         VARCHAR(128) DEFAULT NULL,  -- 编队花名册（逗号分隔；最后一项为队长）
  character_scale                FLOAT DEFAULT NULL,  -- 角色渲染缩放
  collision_radius               FLOAT DEFAULT NULL,  -- 单位移动碰撞体半径
  member_collision_radius        FLOAT DEFAULT NULL,  -- 单名队员的圆形判定体半径
  formation_side                 FLOAT DEFAULT NULL,  -- 三角阵型边长
  red_zone_clearance             FLOAT DEFAULT NULL,  -- 与红色屏蔽区边缘保持的安全距离
  member_separation              FLOAT DEFAULT NULL,  -- 队员之间的最小间距
  member_enemy_separation        FLOAT DEFAULT NULL,  -- 队员与敌方单位之间的隔离距离
  regen_delay                    INT DEFAULT NULL,  -- 距上次受击多久开始回血（毫秒）
  regen_per_second               FLOAT DEFAULT NULL,  -- 每秒恢复的最大生命值比例
  detonate_delay                 INT DEFAULT NULL,  -- 血条耗尽到自爆/引爆的延迟（毫秒）
  detonate_radius                FLOAT DEFAULT NULL,  -- 自爆半径（像素）
  detonate_damage                FLOAT DEFAULT NULL,  -- 爆心伤害
  detonate_damage_falloff        FLOAT DEFAULT NULL,  -- 每档伤害递减比例
  detonate_falloff_step          FLOAT DEFAULT NULL,  -- 伤害递减档距（像素）
  charge_speed                   FLOAT DEFAULT NULL,  -- 阵亡冲锋速度（像素/秒）
  charge_trigger_distance        FLOAT DEFAULT NULL,  -- 贴上该距离立即自爆（像素）
  death_tint_duration            INT DEFAULT NULL,  -- 阵亡泛红时长（毫秒）
  death_tint_strength            FLOAT DEFAULT NULL,  -- 阵亡泛红强度
  track_range                    FLOAT DEFAULT NULL,  -- 追踪范围（敌方 AI，像素）
  attack_release_margin          FLOAT DEFAULT NULL,  -- 停火迟滞带（像素）
  track_release_margin           FLOAT DEFAULT NULL,  -- 放弃追踪迟滞带（像素）
  -- ---- 部署扣点（经济）----
  deploy_cost                    INT DEFAULT NULL,  -- 驻场削点：场上每存在一个该兵种，每分钟可获得的点数上限减少该值（不直接扣当前点数）
  -- ---- 队员隔离与归队（我方）----
  member_separation_max_push     FLOAT DEFAULT NULL,  -- 队员隔离每帧最大推挤位移（像素）
  member_anim_max_step           FLOAT DEFAULT NULL,  -- 队员渲染位置每帧最大位移（像素）
  member_return_distance         FLOAT DEFAULT NULL,  -- 掉队判定距离（像素）
  member_return_exit_ratio       FLOAT DEFAULT NULL,  -- 归队迟滞比例：收进「判定距离 × 该比例」以内才算归位
  member_return_extra_clearance  FLOAT DEFAULT NULL,  -- 归位通道净空额外量（像素），最终净空 = red_zone_clearance + 该值
  member_return_speed            FLOAT DEFAULT NULL,  -- 归队移动速度（像素/秒）
  member_return_replan_distance  FLOAT DEFAULT NULL,  -- 归队路径的重新规划距离阈值（像素）
  member_return_waypoint_radius  FLOAT DEFAULT NULL,  -- 归队路径拐点的到达判定距离（像素）
  -- ---- 阵型与收拢（我方）----
  squad_regroup_arrive           FLOAT DEFAULT NULL,  -- 归位判定距离（像素）
  squad_regroup_catchup_distance FLOAT DEFAULT NULL,  -- 落后该距离后开始提速归队（像素）
  squad_regroup_stall_ratio      FLOAT DEFAULT NULL,  -- 单帧靠近量不足预算的该比例即累计卡滞
  squad_regroup_stall_frames     INT DEFAULT NULL,  -- 连续卡滞帧数达到该值即视为已归位
  squad_free_return_ratio        FLOAT DEFAULT NULL,  -- 超出自由散开范围后的回收速度倍率（相对行军速度）
  squad_separation_target        FLOAT DEFAULT NULL,  -- 队形被挤压时的兜底隔离距离（像素）
  squad_separation_buffer        FLOAT DEFAULT NULL,  -- 队形隔离的收敛容差
  squad_order_spread             FLOAT DEFAULT NULL,  -- 多队同时移动时终点圆环分摊半径（像素）：越小越贴近点击点，取值需保证相邻小队贴近而不相叠
  squad_separation_passes        INT DEFAULT NULL,  -- 队员隔离与红区净空交替求解轮数
  squad_edge_range               FLOAT DEFAULT NULL,  -- 判定「已贴到红色屏蔽区边缘」的额外距离（像素）
  squad_edge_exit_range          FLOAT DEFAULT NULL,  -- 贴红区判定的退出迟滞距离（像素）
  squad_formation_lerp           FLOAT DEFAULT NULL,  -- 行进方向插值系数（避免拐角处方向跳变）
  squad_morph_duration           INT DEFAULT NULL,  -- 三角阵型与自由散开的过渡时长（毫秒）
  squad_free_spread              FLOAT DEFAULT NULL,  -- 自由移动时的横向展开量（像素）
  squad_free_max_distance        FLOAT DEFAULT NULL,  -- 队员与队形中心的最大距离（像素）
  squad_free_back_left           FLOAT DEFAULT NULL,  -- 自由站位「左侧」沿行进方向的落后量（像素）
  squad_free_back_apex           FLOAT DEFAULT NULL,  -- 自由站位「中间」沿行进方向的落后量（像素，负为更靠前）
  squad_free_back_right          FLOAT DEFAULT NULL,  -- 自由站位「右侧」沿行进方向的落后量（像素）
  squad_slot_swap_blend          FLOAT DEFAULT NULL,  -- 允许重新分配站位所需的散开完成度
  -- ---- 动画（我方）----
  animation_mix_attack           FLOAT DEFAULT NULL,  -- 攻击与移动/待机交叉淡化时长（秒）
  animation_mix_loop             FLOAT DEFAULT NULL,  -- 移动与待机交叉淡化时长（秒）
  attack_animation_fallback      INT DEFAULT NULL,  -- 取不到攻击动画时长时的兜底锁定时长（毫秒）
  animation_lock_grace           FLOAT DEFAULT NULL,  -- 一次性动画尾帧保留容差（毫秒）
  spawn_animation_duration       INT DEFAULT NULL,  -- 出生动画时长（毫秒）
  spawn_animation_min_scale      FLOAT DEFAULT NULL,  -- 出生动画起始缩放（相对正常体型）
  -- ---- 红区绕行与移动容错（我方）----
  red_route_range                FLOAT DEFAULT NULL,  -- 「移动路线范围内」的红区判定半径（像素）
  red_steer_bias                 FLOAT DEFAULT NULL,  -- 沿红色屏蔽区行走时的额外外扩量（保证净空足额）
  move_stall_timeout             INT DEFAULT NULL,  -- 贴着红区打转、长时间无法靠近终点的判定时长（毫秒）
  move_progress_epsilon          FLOAT DEFAULT NULL,  -- 判定「确实靠近了终点」的最小距离（像素）
  charge_retarget_interval       INT DEFAULT NULL,  -- 阵亡冲锋的重新索敌间隔（毫秒）
  -- ---- 视觉尺寸 ----
  bar_width                      FLOAT DEFAULT NULL,  -- 血条宽度（像素）
  shadow_width_ratio             FLOAT DEFAULT NULL,  -- 脚下阴影宽度 / 单位显示宽度
  shadow_flatten                 FLOAT DEFAULT NULL,  -- 脚下阴影高度 / 宽度
  shadow_alpha                   FLOAT DEFAULT NULL,  -- 脚下阴影透明度
  shadow_offset_y                FLOAT DEFAULT NULL,  -- 脚下阴影相对单位原点的纵向偏移（像素）
  ring_width                     FLOAT DEFAULT NULL,  -- 脚下选中圆环宽度（像素）
  ring_height                    FLOAT DEFAULT NULL,  -- 脚下选中圆环高度（像素）
  ring_offset_y                  FLOAT DEFAULT NULL,  -- 脚下选中圆环纵向偏移（像素）
  -- ---- 敌方 AI 与行动路线 ----
  hold_duration                  INT DEFAULT NULL,  -- 行动点待机时长（毫秒）
  patrol_radius                  FLOAT DEFAULT NULL,  -- 待机巡逻范围半径（像素）
  patrol_min_radius              FLOAT DEFAULT NULL,  -- 巡逻折返的最小半径（像素）
  patrol_slack                   FLOAT DEFAULT NULL,  -- 巡逻硬约束容差（像素）
  endpoint_roam_radius           FLOAT DEFAULT NULL,  -- 路线终点自由待机区域半径（像素）
  endpoint_idle_min              INT DEFAULT NULL,  -- 终点到位后随机静止时长下限（毫秒）
  endpoint_idle_max              INT DEFAULT NULL,  -- 终点到位后随机静止时长上限（毫秒）
  endpoint_return_slack_factor   FLOAT DEFAULT NULL,  -- 终点回位距离 = 待机半径 + patrol_slack × 该系数
  route_corridor                 FLOAT DEFAULT NULL,  -- 移动路线走廊半宽（像素）
  route_variant_count            INT DEFAULT NULL,  -- 每条主路线生成的随机变体数量
  spawn_offmap_padding           FLOAT DEFAULT NULL,  -- 出生点在地图外额外补足的入场距离（像素）
  separation_strength            FLOAT DEFAULT NULL,  -- 单位隔离每帧推开重叠量的比例
  separation_max_push            FLOAT DEFAULT NULL,  -- 单位隔离每帧最大推挤位移（像素）
  replan_cooldown                INT DEFAULT NULL,  -- 路径重规划冷却（毫秒）
  stuck_time                     INT DEFAULT NULL,  -- 卡滞判定时长（毫秒）
  stuck_distance                 FLOAT DEFAULT NULL,  -- 卡滞判定位移阈值（像素）
  attack_contact_tolerance       FLOAT DEFAULT NULL,  -- 进入攻击范围的到位容差（像素）
  attack_animation_loop          INT DEFAULT NULL,  -- 攻击姿态是否循环播放（1 = 循环）
  knockback_distance             FLOAT DEFAULT NULL,  -- 被击中后的击退距离（像素）
  knockback_duration             INT DEFAULT NULL  -- 被击中后的击退持续时间（毫秒）
);

DROP TABLE IF EXISTS enemy_heavy;
CREATE TABLE enemy_heavy (  -- 敌方重甲，id 待定
  unit_id                        VARCHAR(32) NOT NULL PRIMARY KEY,  -- 单位唯一标识
  unit_name                      VARCHAR(32) DEFAULT NULL,  -- 显示名
  cost                           INT NOT NULL DEFAULT 0,  -- 招募消耗：出兵时从可用点数中一次性扣除的点数
  build_time                     FLOAT NOT NULL DEFAULT 0,  -- 训练耗时（秒）
  max_hp                         INT NOT NULL DEFAULT 1,  -- 最大生命值
  armor                          INT NOT NULL DEFAULT 0,  -- 固定减伤护甲
  move_speed                     FLOAT NOT NULL DEFAULT 0,  -- 移动速度（像素/秒）
  action_range                   FLOAT NOT NULL DEFAULT 0,  -- 攻击/作用距离（像素）
  action_value                   INT NOT NULL DEFAULT 0,  -- 作用数值（正为伤害/治疗）
  action_cd                      FLOAT NOT NULL DEFAULT 0,  -- 技能冷却/攻击间隔（秒）
  target_type                    INT NOT NULL DEFAULT 0 CHECK (target_type IN (0, 1)),  -- 作用目标判定：0 = 敌方单位，1 = 我方单位（支援单位对我方回血用）
  armor_penetration              INT NOT NULL DEFAULT 0,  -- 破甲值：对拥有护甲的敌人能减去的护甲值
  -- ---- 以下为代码内使用的静态数值（自定字段名与类型）----
  squad_size                     INT DEFAULT 1,  -- 编队人数：多人独立碰撞体、合并为一个基本单位
  roster                         VARCHAR(128) DEFAULT NULL,  -- 编队花名册（逗号分隔；最后一项为队长）
  character_scale                FLOAT DEFAULT NULL,  -- 角色渲染缩放
  collision_radius               FLOAT DEFAULT NULL,  -- 单位移动碰撞体半径
  member_collision_radius        FLOAT DEFAULT NULL,  -- 单名队员的圆形判定体半径
  formation_side                 FLOAT DEFAULT NULL,  -- 三角阵型边长
  red_zone_clearance             FLOAT DEFAULT NULL,  -- 与红色屏蔽区边缘保持的安全距离
  member_separation              FLOAT DEFAULT NULL,  -- 队员之间的最小间距
  member_enemy_separation        FLOAT DEFAULT NULL,  -- 队员与敌方单位之间的隔离距离
  regen_delay                    INT DEFAULT NULL,  -- 距上次受击多久开始回血（毫秒）
  regen_per_second               FLOAT DEFAULT NULL,  -- 每秒恢复的最大生命值比例
  detonate_delay                 INT DEFAULT NULL,  -- 血条耗尽到自爆/引爆的延迟（毫秒）
  detonate_radius                FLOAT DEFAULT NULL,  -- 自爆半径（像素）
  detonate_damage                FLOAT DEFAULT NULL,  -- 爆心伤害
  detonate_damage_falloff        FLOAT DEFAULT NULL,  -- 每档伤害递减比例
  detonate_falloff_step          FLOAT DEFAULT NULL,  -- 伤害递减档距（像素）
  charge_speed                   FLOAT DEFAULT NULL,  -- 阵亡冲锋速度（像素/秒）
  charge_trigger_distance        FLOAT DEFAULT NULL,  -- 贴上该距离立即自爆（像素）
  death_tint_duration            INT DEFAULT NULL,  -- 阵亡泛红时长（毫秒）
  death_tint_strength            FLOAT DEFAULT NULL,  -- 阵亡泛红强度
  track_range                    FLOAT DEFAULT NULL,  -- 追踪范围（敌方 AI，像素）
  attack_release_margin          FLOAT DEFAULT NULL,  -- 停火迟滞带（像素）
  track_release_margin           FLOAT DEFAULT NULL,  -- 放弃追踪迟滞带（像素）
  -- ---- 部署扣点（经济）----
  deploy_cost                    INT DEFAULT NULL,  -- 驻场削点：场上每存在一个该兵种，每分钟可获得的点数上限减少该值（不直接扣当前点数）
  -- ---- 队员隔离与归队（我方）----
  member_separation_max_push     FLOAT DEFAULT NULL,  -- 队员隔离每帧最大推挤位移（像素）
  member_anim_max_step           FLOAT DEFAULT NULL,  -- 队员渲染位置每帧最大位移（像素）
  member_return_distance         FLOAT DEFAULT NULL,  -- 掉队判定距离（像素）
  member_return_exit_ratio       FLOAT DEFAULT NULL,  -- 归队迟滞比例：收进「判定距离 × 该比例」以内才算归位
  member_return_extra_clearance  FLOAT DEFAULT NULL,  -- 归位通道净空额外量（像素），最终净空 = red_zone_clearance + 该值
  member_return_speed            FLOAT DEFAULT NULL,  -- 归队移动速度（像素/秒）
  member_return_replan_distance  FLOAT DEFAULT NULL,  -- 归队路径的重新规划距离阈值（像素）
  member_return_waypoint_radius  FLOAT DEFAULT NULL,  -- 归队路径拐点的到达判定距离（像素）
  -- ---- 阵型与收拢（我方）----
  squad_regroup_arrive           FLOAT DEFAULT NULL,  -- 归位判定距离（像素）
  squad_regroup_catchup_distance FLOAT DEFAULT NULL,  -- 落后该距离后开始提速归队（像素）
  squad_regroup_stall_ratio      FLOAT DEFAULT NULL,  -- 单帧靠近量不足预算的该比例即累计卡滞
  squad_regroup_stall_frames     INT DEFAULT NULL,  -- 连续卡滞帧数达到该值即视为已归位
  squad_free_return_ratio        FLOAT DEFAULT NULL,  -- 超出自由散开范围后的回收速度倍率（相对行军速度）
  squad_separation_target        FLOAT DEFAULT NULL,  -- 队形被挤压时的兜底隔离距离（像素）
  squad_separation_buffer        FLOAT DEFAULT NULL,  -- 队形隔离的收敛容差
  squad_order_spread             FLOAT DEFAULT NULL,  -- 多队同时移动时终点圆环分摊半径（像素）：越小越贴近点击点，取值需保证相邻小队贴近而不相叠
  squad_separation_passes        INT DEFAULT NULL,  -- 队员隔离与红区净空交替求解轮数
  squad_edge_range               FLOAT DEFAULT NULL,  -- 判定「已贴到红色屏蔽区边缘」的额外距离（像素）
  squad_edge_exit_range          FLOAT DEFAULT NULL,  -- 贴红区判定的退出迟滞距离（像素）
  squad_formation_lerp           FLOAT DEFAULT NULL,  -- 行进方向插值系数（避免拐角处方向跳变）
  squad_morph_duration           INT DEFAULT NULL,  -- 三角阵型与自由散开的过渡时长（毫秒）
  squad_free_spread              FLOAT DEFAULT NULL,  -- 自由移动时的横向展开量（像素）
  squad_free_max_distance        FLOAT DEFAULT NULL,  -- 队员与队形中心的最大距离（像素）
  squad_free_back_left           FLOAT DEFAULT NULL,  -- 自由站位「左侧」沿行进方向的落后量（像素）
  squad_free_back_apex           FLOAT DEFAULT NULL,  -- 自由站位「中间」沿行进方向的落后量（像素，负为更靠前）
  squad_free_back_right          FLOAT DEFAULT NULL,  -- 自由站位「右侧」沿行进方向的落后量（像素）
  squad_slot_swap_blend          FLOAT DEFAULT NULL,  -- 允许重新分配站位所需的散开完成度
  -- ---- 动画（我方）----
  animation_mix_attack           FLOAT DEFAULT NULL,  -- 攻击与移动/待机交叉淡化时长（秒）
  animation_mix_loop             FLOAT DEFAULT NULL,  -- 移动与待机交叉淡化时长（秒）
  attack_animation_fallback      INT DEFAULT NULL,  -- 取不到攻击动画时长时的兜底锁定时长（毫秒）
  animation_lock_grace           FLOAT DEFAULT NULL,  -- 一次性动画尾帧保留容差（毫秒）
  spawn_animation_duration       INT DEFAULT NULL,  -- 出生动画时长（毫秒）
  spawn_animation_min_scale      FLOAT DEFAULT NULL,  -- 出生动画起始缩放（相对正常体型）
  -- ---- 红区绕行与移动容错（我方）----
  red_route_range                FLOAT DEFAULT NULL,  -- 「移动路线范围内」的红区判定半径（像素）
  red_steer_bias                 FLOAT DEFAULT NULL,  -- 沿红色屏蔽区行走时的额外外扩量（保证净空足额）
  move_stall_timeout             INT DEFAULT NULL,  -- 贴着红区打转、长时间无法靠近终点的判定时长（毫秒）
  move_progress_epsilon          FLOAT DEFAULT NULL,  -- 判定「确实靠近了终点」的最小距离（像素）
  charge_retarget_interval       INT DEFAULT NULL,  -- 阵亡冲锋的重新索敌间隔（毫秒）
  -- ---- 视觉尺寸 ----
  bar_width                      FLOAT DEFAULT NULL,  -- 血条宽度（像素）
  shadow_width_ratio             FLOAT DEFAULT NULL,  -- 脚下阴影宽度 / 单位显示宽度
  shadow_flatten                 FLOAT DEFAULT NULL,  -- 脚下阴影高度 / 宽度
  shadow_alpha                   FLOAT DEFAULT NULL,  -- 脚下阴影透明度
  shadow_offset_y                FLOAT DEFAULT NULL,  -- 脚下阴影相对单位原点的纵向偏移（像素）
  ring_width                     FLOAT DEFAULT NULL,  -- 脚下选中圆环宽度（像素）
  ring_height                    FLOAT DEFAULT NULL,  -- 脚下选中圆环高度（像素）
  ring_offset_y                  FLOAT DEFAULT NULL,  -- 脚下选中圆环纵向偏移（像素）
  -- ---- 敌方 AI 与行动路线 ----
  hold_duration                  INT DEFAULT NULL,  -- 行动点待机时长（毫秒）
  patrol_radius                  FLOAT DEFAULT NULL,  -- 待机巡逻范围半径（像素）
  patrol_min_radius              FLOAT DEFAULT NULL,  -- 巡逻折返的最小半径（像素）
  patrol_slack                   FLOAT DEFAULT NULL,  -- 巡逻硬约束容差（像素）
  endpoint_roam_radius           FLOAT DEFAULT NULL,  -- 路线终点自由待机区域半径（像素）
  endpoint_idle_min              INT DEFAULT NULL,  -- 终点到位后随机静止时长下限（毫秒）
  endpoint_idle_max              INT DEFAULT NULL,  -- 终点到位后随机静止时长上限（毫秒）
  endpoint_return_slack_factor   FLOAT DEFAULT NULL,  -- 终点回位距离 = 待机半径 + patrol_slack × 该系数
  route_corridor                 FLOAT DEFAULT NULL,  -- 移动路线走廊半宽（像素）
  route_variant_count            INT DEFAULT NULL,  -- 每条主路线生成的随机变体数量
  spawn_offmap_padding           FLOAT DEFAULT NULL,  -- 出生点在地图外额外补足的入场距离（像素）
  separation_strength            FLOAT DEFAULT NULL,  -- 单位隔离每帧推开重叠量的比例
  separation_max_push            FLOAT DEFAULT NULL,  -- 单位隔离每帧最大推挤位移（像素）
  replan_cooldown                INT DEFAULT NULL,  -- 路径重规划冷却（毫秒）
  stuck_time                     INT DEFAULT NULL,  -- 卡滞判定时长（毫秒）
  stuck_distance                 FLOAT DEFAULT NULL,  -- 卡滞判定位移阈值（像素）
  attack_contact_tolerance       FLOAT DEFAULT NULL,  -- 进入攻击范围的到位容差（像素）
  attack_animation_loop          INT DEFAULT NULL,  -- 攻击姿态是否循环播放（1 = 循环）
  knockback_distance             FLOAT DEFAULT NULL,  -- 被击中后的击退距离（像素）
  knockback_duration             INT DEFAULT NULL  -- 被击中后的击退持续时间（毫秒）
);

DROP TABLE IF EXISTS enemy_support;
CREATE TABLE enemy_support (  -- 敌方支援，id 待定
  unit_id                        VARCHAR(32) NOT NULL PRIMARY KEY,  -- 单位唯一标识
  unit_name                      VARCHAR(32) DEFAULT NULL,  -- 显示名
  cost                           INT NOT NULL DEFAULT 0,  -- 招募消耗：出兵时从可用点数中一次性扣除的点数
  build_time                     FLOAT NOT NULL DEFAULT 0,  -- 训练耗时（秒）
  max_hp                         INT NOT NULL DEFAULT 1,  -- 最大生命值
  armor                          INT NOT NULL DEFAULT 0,  -- 固定减伤护甲
  move_speed                     FLOAT NOT NULL DEFAULT 0,  -- 移动速度（像素/秒）
  action_range                   FLOAT NOT NULL DEFAULT 0,  -- 攻击/作用距离（像素）
  action_value                   INT NOT NULL DEFAULT 0,  -- 作用数值（正为伤害/治疗）
  action_cd                      FLOAT NOT NULL DEFAULT 0,  -- 技能冷却/攻击间隔（秒）
  target_type                    INT NOT NULL DEFAULT 0 CHECK (target_type IN (0, 1)),  -- 作用目标判定：0 = 敌方单位，1 = 我方单位（支援单位对我方回血用）
  armor_penetration              INT NOT NULL DEFAULT 0,  -- 破甲值：对拥有护甲的敌人能减去的护甲值
  -- ---- 以下为代码内使用的静态数值（自定字段名与类型）----
  squad_size                     INT DEFAULT 1,  -- 编队人数：多人独立碰撞体、合并为一个基本单位
  roster                         VARCHAR(128) DEFAULT NULL,  -- 编队花名册（逗号分隔；最后一项为队长）
  character_scale                FLOAT DEFAULT NULL,  -- 角色渲染缩放
  collision_radius               FLOAT DEFAULT NULL,  -- 单位移动碰撞体半径
  member_collision_radius        FLOAT DEFAULT NULL,  -- 单名队员的圆形判定体半径
  formation_side                 FLOAT DEFAULT NULL,  -- 三角阵型边长
  red_zone_clearance             FLOAT DEFAULT NULL,  -- 与红色屏蔽区边缘保持的安全距离
  member_separation              FLOAT DEFAULT NULL,  -- 队员之间的最小间距
  member_enemy_separation        FLOAT DEFAULT NULL,  -- 队员与敌方单位之间的隔离距离
  regen_delay                    INT DEFAULT NULL,  -- 距上次受击多久开始回血（毫秒）
  regen_per_second               FLOAT DEFAULT NULL,  -- 每秒恢复的最大生命值比例
  detonate_delay                 INT DEFAULT NULL,  -- 血条耗尽到自爆/引爆的延迟（毫秒）
  detonate_radius                FLOAT DEFAULT NULL,  -- 自爆半径（像素）
  detonate_damage                FLOAT DEFAULT NULL,  -- 爆心伤害
  detonate_damage_falloff        FLOAT DEFAULT NULL,  -- 每档伤害递减比例
  detonate_falloff_step          FLOAT DEFAULT NULL,  -- 伤害递减档距（像素）
  charge_speed                   FLOAT DEFAULT NULL,  -- 阵亡冲锋速度（像素/秒）
  charge_trigger_distance        FLOAT DEFAULT NULL,  -- 贴上该距离立即自爆（像素）
  death_tint_duration            INT DEFAULT NULL,  -- 阵亡泛红时长（毫秒）
  death_tint_strength            FLOAT DEFAULT NULL,  -- 阵亡泛红强度
  track_range                    FLOAT DEFAULT NULL,  -- 追踪范围（敌方 AI，像素）
  attack_release_margin          FLOAT DEFAULT NULL,  -- 停火迟滞带（像素）
  track_release_margin           FLOAT DEFAULT NULL,  -- 放弃追踪迟滞带（像素）
  -- ---- 部署扣点（经济）----
  deploy_cost                    INT DEFAULT NULL,  -- 驻场削点：场上每存在一个该兵种，每分钟可获得的点数上限减少该值（不直接扣当前点数）
  -- ---- 队员隔离与归队（我方）----
  member_separation_max_push     FLOAT DEFAULT NULL,  -- 队员隔离每帧最大推挤位移（像素）
  member_anim_max_step           FLOAT DEFAULT NULL,  -- 队员渲染位置每帧最大位移（像素）
  member_return_distance         FLOAT DEFAULT NULL,  -- 掉队判定距离（像素）
  member_return_exit_ratio       FLOAT DEFAULT NULL,  -- 归队迟滞比例：收进「判定距离 × 该比例」以内才算归位
  member_return_extra_clearance  FLOAT DEFAULT NULL,  -- 归位通道净空额外量（像素），最终净空 = red_zone_clearance + 该值
  member_return_speed            FLOAT DEFAULT NULL,  -- 归队移动速度（像素/秒）
  member_return_replan_distance  FLOAT DEFAULT NULL,  -- 归队路径的重新规划距离阈值（像素）
  member_return_waypoint_radius  FLOAT DEFAULT NULL,  -- 归队路径拐点的到达判定距离（像素）
  -- ---- 阵型与收拢（我方）----
  squad_regroup_arrive           FLOAT DEFAULT NULL,  -- 归位判定距离（像素）
  squad_regroup_catchup_distance FLOAT DEFAULT NULL,  -- 落后该距离后开始提速归队（像素）
  squad_regroup_stall_ratio      FLOAT DEFAULT NULL,  -- 单帧靠近量不足预算的该比例即累计卡滞
  squad_regroup_stall_frames     INT DEFAULT NULL,  -- 连续卡滞帧数达到该值即视为已归位
  squad_free_return_ratio        FLOAT DEFAULT NULL,  -- 超出自由散开范围后的回收速度倍率（相对行军速度）
  squad_separation_target        FLOAT DEFAULT NULL,  -- 队形被挤压时的兜底隔离距离（像素）
  squad_separation_buffer        FLOAT DEFAULT NULL,  -- 队形隔离的收敛容差
  squad_order_spread             FLOAT DEFAULT NULL,  -- 多队同时移动时终点圆环分摊半径（像素）：越小越贴近点击点，取值需保证相邻小队贴近而不相叠
  squad_separation_passes        INT DEFAULT NULL,  -- 队员隔离与红区净空交替求解轮数
  squad_edge_range               FLOAT DEFAULT NULL,  -- 判定「已贴到红色屏蔽区边缘」的额外距离（像素）
  squad_edge_exit_range          FLOAT DEFAULT NULL,  -- 贴红区判定的退出迟滞距离（像素）
  squad_formation_lerp           FLOAT DEFAULT NULL,  -- 行进方向插值系数（避免拐角处方向跳变）
  squad_morph_duration           INT DEFAULT NULL,  -- 三角阵型与自由散开的过渡时长（毫秒）
  squad_free_spread              FLOAT DEFAULT NULL,  -- 自由移动时的横向展开量（像素）
  squad_free_max_distance        FLOAT DEFAULT NULL,  -- 队员与队形中心的最大距离（像素）
  squad_free_back_left           FLOAT DEFAULT NULL,  -- 自由站位「左侧」沿行进方向的落后量（像素）
  squad_free_back_apex           FLOAT DEFAULT NULL,  -- 自由站位「中间」沿行进方向的落后量（像素，负为更靠前）
  squad_free_back_right          FLOAT DEFAULT NULL,  -- 自由站位「右侧」沿行进方向的落后量（像素）
  squad_slot_swap_blend          FLOAT DEFAULT NULL,  -- 允许重新分配站位所需的散开完成度
  -- ---- 动画（我方）----
  animation_mix_attack           FLOAT DEFAULT NULL,  -- 攻击与移动/待机交叉淡化时长（秒）
  animation_mix_loop             FLOAT DEFAULT NULL,  -- 移动与待机交叉淡化时长（秒）
  attack_animation_fallback      INT DEFAULT NULL,  -- 取不到攻击动画时长时的兜底锁定时长（毫秒）
  animation_lock_grace           FLOAT DEFAULT NULL,  -- 一次性动画尾帧保留容差（毫秒）
  spawn_animation_duration       INT DEFAULT NULL,  -- 出生动画时长（毫秒）
  spawn_animation_min_scale      FLOAT DEFAULT NULL,  -- 出生动画起始缩放（相对正常体型）
  -- ---- 红区绕行与移动容错（我方）----
  red_route_range                FLOAT DEFAULT NULL,  -- 「移动路线范围内」的红区判定半径（像素）
  red_steer_bias                 FLOAT DEFAULT NULL,  -- 沿红色屏蔽区行走时的额外外扩量（保证净空足额）
  move_stall_timeout             INT DEFAULT NULL,  -- 贴着红区打转、长时间无法靠近终点的判定时长（毫秒）
  move_progress_epsilon          FLOAT DEFAULT NULL,  -- 判定「确实靠近了终点」的最小距离（像素）
  charge_retarget_interval       INT DEFAULT NULL,  -- 阵亡冲锋的重新索敌间隔（毫秒）
  -- ---- 视觉尺寸 ----
  bar_width                      FLOAT DEFAULT NULL,  -- 血条宽度（像素）
  shadow_width_ratio             FLOAT DEFAULT NULL,  -- 脚下阴影宽度 / 单位显示宽度
  shadow_flatten                 FLOAT DEFAULT NULL,  -- 脚下阴影高度 / 宽度
  shadow_alpha                   FLOAT DEFAULT NULL,  -- 脚下阴影透明度
  shadow_offset_y                FLOAT DEFAULT NULL,  -- 脚下阴影相对单位原点的纵向偏移（像素）
  ring_width                     FLOAT DEFAULT NULL,  -- 脚下选中圆环宽度（像素）
  ring_height                    FLOAT DEFAULT NULL,  -- 脚下选中圆环高度（像素）
  ring_offset_y                  FLOAT DEFAULT NULL,  -- 脚下选中圆环纵向偏移（像素）
  -- ---- 敌方 AI 与行动路线 ----
  hold_duration                  INT DEFAULT NULL,  -- 行动点待机时长（毫秒）
  patrol_radius                  FLOAT DEFAULT NULL,  -- 待机巡逻范围半径（像素）
  patrol_min_radius              FLOAT DEFAULT NULL,  -- 巡逻折返的最小半径（像素）
  patrol_slack                   FLOAT DEFAULT NULL,  -- 巡逻硬约束容差（像素）
  endpoint_roam_radius           FLOAT DEFAULT NULL,  -- 路线终点自由待机区域半径（像素）
  endpoint_idle_min              INT DEFAULT NULL,  -- 终点到位后随机静止时长下限（毫秒）
  endpoint_idle_max              INT DEFAULT NULL,  -- 终点到位后随机静止时长上限（毫秒）
  endpoint_return_slack_factor   FLOAT DEFAULT NULL,  -- 终点回位距离 = 待机半径 + patrol_slack × 该系数
  route_corridor                 FLOAT DEFAULT NULL,  -- 移动路线走廊半宽（像素）
  route_variant_count            INT DEFAULT NULL,  -- 每条主路线生成的随机变体数量
  spawn_offmap_padding           FLOAT DEFAULT NULL,  -- 出生点在地图外额外补足的入场距离（像素）
  separation_strength            FLOAT DEFAULT NULL,  -- 单位隔离每帧推开重叠量的比例
  separation_max_push            FLOAT DEFAULT NULL,  -- 单位隔离每帧最大推挤位移（像素）
  replan_cooldown                INT DEFAULT NULL,  -- 路径重规划冷却（毫秒）
  stuck_time                     INT DEFAULT NULL,  -- 卡滞判定时长（毫秒）
  stuck_distance                 FLOAT DEFAULT NULL,  -- 卡滞判定位移阈值（像素）
  attack_contact_tolerance       FLOAT DEFAULT NULL,  -- 进入攻击范围的到位容差（像素）
  attack_animation_loop          INT DEFAULT NULL,  -- 攻击姿态是否循环播放（1 = 循环）
  knockback_distance             FLOAT DEFAULT NULL,  -- 被击中后的击退距离（像素）
  knockback_duration             INT DEFAULT NULL  -- 被击中后的击退持续时间（毫秒）
);

INSERT INTO player_infantry (
  unit_id,
  unit_name,
  cost,
  build_time,
  max_hp,
  armor,
  move_speed,
  action_range,
  action_value,
  action_cd,
  target_type,
  armor_penetration,
  squad_size,
  roster,
  character_scale,
  collision_radius,
  member_collision_radius,
  formation_side,
  red_zone_clearance,
  member_separation,
  member_enemy_separation,
  regen_delay,
  regen_per_second,
  detonate_delay,
  detonate_radius,
  detonate_damage,
  detonate_damage_falloff,
  detonate_falloff_step,
  charge_speed,
  charge_trigger_distance,
  death_tint_duration,
  death_tint_strength,
  track_range,
  attack_release_margin,
  track_release_margin,
  deploy_cost,
  member_separation_max_push,
  member_anim_max_step,
  member_return_distance,
  member_return_exit_ratio,
  member_return_extra_clearance,
  member_return_speed,
  member_return_replan_distance,
  member_return_waypoint_radius,
  squad_regroup_arrive,
  squad_regroup_catchup_distance,
  squad_regroup_stall_ratio,
  squad_regroup_stall_frames,
  squad_free_return_ratio,
  squad_separation_target,
  squad_separation_buffer,
  squad_order_spread,
  squad_separation_passes,
  squad_edge_range,
  squad_edge_exit_range,
  squad_formation_lerp,
  squad_morph_duration,
  squad_free_spread,
  squad_free_max_distance,
  squad_free_back_left,
  squad_free_back_apex,
  squad_free_back_right,
  squad_slot_swap_blend,
  animation_mix_attack,
  animation_mix_loop,
  attack_animation_fallback,
  animation_lock_grace,
  spawn_animation_duration,
  spawn_animation_min_scale,
  red_route_range,
  red_steer_bias,
  move_stall_timeout,
  move_progress_epsilon,
  charge_retarget_interval,
  bar_width,
  shadow_width_ratio,
  shadow_flatten,
  shadow_alpha,
  shadow_offset_y,
  ring_width,
  ring_height,
  ring_offset_y,
  hold_duration,
  patrol_radius,
  patrol_min_radius,
  patrol_slack,
  endpoint_roam_radius,
  endpoint_idle_min,
  endpoint_idle_max,
  endpoint_return_slack_factor,
  route_corridor,
  route_variant_count,
  spawn_offmap_padding,
  separation_strength,
  separation_max_push,
  replan_cooldown,
  stuck_time,
  stuck_distance,
  attack_contact_tolerance,
  attack_animation_loop,
  knockback_distance,
  knockback_duration
) VALUES (
  'JF',
  'JF',
  40,
  30,
  30,
  8,
  187.5,
  300,
  3,
  0.65,
  0,
  8,
  3,
  'Jiangyu,Qiongjiu,Daiyan',
  0.5625,
  30,
  17,
  56.5,
  19,
  19,
  37.5,
  5000,
  0.05,
  5000,
  40,
  20,
  0.2,
  10,
  244,
  37.5,
  900,
  0.25,
  NULL,
  NULL,
  NULL,
  10,
  7.5,
  4.9,
  112.5,
  0.5,
  7.5,
  262.5,
  75,
  7.5,
  2.8,
  30,
  0.25,
  20,
  1.15,
  28,
  0.05,
  60,
  6,
  11.5,
  26.5,
  0.25,
  560,
  30,
  86.5,
  11.5,
  -19,
  7.5,
  0.97,
  0.12,
  0.16,
  600,
  20,
  720,
  0.3,
  281.5,
  0.15,
  1600,
  0.95,
  300,
  37.5,
  0.66,
  0.27,
  0.32,
  2,
  37.5,
  17,
  4,
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  NULL
);

INSERT INTO enemy_infantry (
  unit_id,
  unit_name,
  cost,
  build_time,
  max_hp,
  armor,
  move_speed,
  action_range,
  action_value,
  action_cd,
  target_type,
  armor_penetration,
  squad_size,
  roster,
  character_scale,
  collision_radius,
  member_collision_radius,
  formation_side,
  red_zone_clearance,
  member_separation,
  member_enemy_separation,
  regen_delay,
  regen_per_second,
  detonate_delay,
  detonate_radius,
  detonate_damage,
  detonate_damage_falloff,
  detonate_falloff_step,
  charge_speed,
  charge_trigger_distance,
  death_tint_duration,
  death_tint_strength,
  track_range,
  attack_release_margin,
  track_release_margin,
  deploy_cost,
  member_separation_max_push,
  member_anim_max_step,
  member_return_distance,
  member_return_exit_ratio,
  member_return_extra_clearance,
  member_return_speed,
  member_return_replan_distance,
  member_return_waypoint_radius,
  squad_regroup_arrive,
  squad_regroup_catchup_distance,
  squad_regroup_stall_ratio,
  squad_regroup_stall_frames,
  squad_free_return_ratio,
  squad_separation_target,
  squad_separation_buffer,
  squad_order_spread,
  squad_separation_passes,
  squad_edge_range,
  squad_edge_exit_range,
  squad_formation_lerp,
  squad_morph_duration,
  squad_free_spread,
  squad_free_max_distance,
  squad_free_back_left,
  squad_free_back_apex,
  squad_free_back_right,
  squad_slot_swap_blend,
  animation_mix_attack,
  animation_mix_loop,
  attack_animation_fallback,
  animation_lock_grace,
  spawn_animation_duration,
  spawn_animation_min_scale,
  red_route_range,
  red_steer_bias,
  move_stall_timeout,
  move_progress_epsilon,
  charge_retarget_interval,
  bar_width,
  shadow_width_ratio,
  shadow_flatten,
  shadow_alpha,
  shadow_offset_y,
  ring_width,
  ring_height,
  ring_offset_y,
  hold_duration,
  patrol_radius,
  patrol_min_radius,
  patrol_slack,
  endpoint_roam_radius,
  endpoint_idle_min,
  endpoint_idle_max,
  endpoint_return_slack_factor,
  route_corridor,
  route_variant_count,
  spawn_offmap_padding,
  separation_strength,
  separation_max_push,
  replan_cooldown,
  stuck_time,
  stuck_distance,
  attack_contact_tolerance,
  attack_animation_loop,
  knockback_distance,
  knockback_duration
) VALUES (
  'Vespid',
  'Vespid',
  0,
  0,
  40,
  8,
  150,
  180,
  2,
  1.1,
  0,
  8,
  1,
  'Vespid',
  0.272,
  20.5,
  NULL,
  NULL,
  19,
  NULL,
  NULL,
  NULL,
  NULL,
  3000,
  20,
  5,
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  240,
  12,
  16,
  0,
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  56.5,
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  5000,
  37.5,
  15,
  22.5,
  187.5,
  1200,
  4000,
  4,
  38,
  5,
  90,
  1,
  7.5,
  700,
  1000,
  9.5,
  2,
  1,
  10,
  500
);

-- ----------------------------------------------------------------------------
-- 占位记录：数值尚未设计，只登记「已存在的兵种」与部署扣点。
-- 出生界面：出兵扣 cost（招募消耗），deploy_cost 只削减每分钟点数上限。
-- 这两个兵种尚未登记 cost，因此先只入库 deploy_cost；补上 cost 后才会显示招募角标。
-- 其余列留空（省略），等设计完成后再补。
-- ----------------------------------------------------------------------------
INSERT INTO player_heavy (unit_id, unit_name, deploy_cost) VALUES (
  'tasa_air',
  'tasa_air',
  30
);

INSERT INTO player_support (unit_id, unit_name, deploy_cost) VALUES (
  'mid',
  'mid',
  20
);
-- ----------------------------------------------------------------------------
-- 示例查询
-- ----------------------------------------------------------------------------
-- 查看我方步兵所有字段：SELECT * FROM player_infantry;
-- 查看各兵种的部署扣点：SELECT unit_id, deploy_cost FROM player_infantry UNION ALL SELECT unit_id, deploy_cost FROM player_heavy UNION ALL SELECT unit_id, deploy_cost FROM player_support;
-- 一眼对比双方现役步兵的表格字段：
--   SELECT unit_id, cost, build_time, max_hp, armor, move_speed, action_range,
--          action_value, action_cd, target_type, armor_penetration
--   FROM player_infantry
--   UNION ALL
--   SELECT unit_id, cost, build_time, max_hp, armor, move_speed, action_range,
--          action_value, action_cd, target_type, armor_penetration
--   FROM enemy_infantry;
-- 按破甲/护甲关系核对伤害（破甲 ≥ 护甲：等额 + 每多 1 点 +10%；破甲 < 护甲：每少 1 点 -10%）：
--   SELECT a.unit_id AS attacker, d.unit_id AS defender,
--          a.action_value * (1 + 0.1 * (a.armor_penetration - d.armor)) AS damage
--   FROM player_infantry a CROSS JOIN enemy_infantry d;

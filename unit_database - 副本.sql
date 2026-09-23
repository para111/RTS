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
-- 本文件与 WG.html 内的运行时数据库 UNIT_DATABASE 同源：
--   改数值时两边都要改——WG.html 供游戏运行读取，本脚本供落库 / 调数值 / 出表使用。
-- 语法：通用 SQL（SQLite / MySQL 均可直接执行），可重复执行（每次先删表再建表）。
-- ============================================================================

DROP TABLE IF EXISTS player_infantry;
CREATE TABLE player_infantry (  -- infantry（现役单位 JF）
  unit_id                   VARCHAR(32) NOT NULL PRIMARY KEY,  -- 单位唯一标识
  unit_name                 VARCHAR(32) DEFAULT NULL,  -- 显示名
  cost                      INT NOT NULL DEFAULT 0,  -- 招募资源消耗（点数）
  build_time                FLOAT NOT NULL DEFAULT 0,  -- 训练耗时（秒）
  max_hp                    INT NOT NULL DEFAULT 1,  -- 最大生命值
  armor                     INT NOT NULL DEFAULT 0,  -- 固定减伤护甲
  move_speed                FLOAT NOT NULL DEFAULT 0,  -- 移动速度（像素/秒）
  action_range              FLOAT NOT NULL DEFAULT 0,  -- 攻击/作用距离（像素）
  action_value              INT NOT NULL DEFAULT 0,  -- 作用数值（正为伤害/治疗）
  action_cd                 FLOAT NOT NULL DEFAULT 0,  -- 技能冷却/攻击间隔（秒）
  target_type               INT NOT NULL DEFAULT 0 CHECK (target_type IN (0, 1)),  -- 作用目标判定：0 = 敌方单位，1 = 我方单位（支援单位对我方回血用）
  armor_penetration         INT NOT NULL DEFAULT 0,  -- 破甲值：对拥有护甲的敌人能减去的护甲值
  -- ---- 以下为代码内使用的静态数值（自定字段名与类型）----
  squad_size                INT DEFAULT 1,  -- 编队人数：多人独立碰撞体、合并为一个基本单位
  roster                    VARCHAR(128) DEFAULT NULL,  -- 编队花名册（逗号分隔）
  character_scale           FLOAT DEFAULT NULL,  -- 角色渲染缩放
  collision_radius          FLOAT DEFAULT NULL,  -- 单位移动碰撞体半径
  member_collision_radius   FLOAT DEFAULT NULL,  -- 单名队员的圆形判定体半径
  formation_side            FLOAT DEFAULT NULL,  -- 三角阵型边长
  red_zone_clearance        FLOAT DEFAULT NULL,  -- 与红色屏蔽区边缘保持的安全距离
  member_separation         FLOAT DEFAULT NULL,  -- 队员之间的最小间距
  member_enemy_separation   FLOAT DEFAULT NULL,  -- 队员与敌方单位之间的隔离距离
  regen_delay               INT DEFAULT NULL,  -- 距上次受击多久开始回血（毫秒）
  regen_per_second          FLOAT DEFAULT NULL,  -- 每秒恢复的最大生命值比例
  detonate_delay            INT DEFAULT NULL,  -- 血条耗尽到自爆/引爆的延迟（毫秒）
  detonate_radius           FLOAT DEFAULT NULL,  -- 自爆半径（像素）
  detonate_damage           FLOAT DEFAULT NULL,  -- 爆心伤害
  detonate_damage_falloff   FLOAT DEFAULT NULL,  -- 每档伤害递减比例
  detonate_falloff_step     FLOAT DEFAULT NULL,  -- 伤害递减档距（像素）
  charge_speed              FLOAT DEFAULT NULL,  -- 阵亡冲锋速度（像素/秒）
  charge_trigger_distance   FLOAT DEFAULT NULL,  -- 贴上该距离立即自爆（像素）
  death_tint_duration       INT DEFAULT NULL,  -- 阵亡泛红时长（毫秒）
  death_tint_strength       FLOAT DEFAULT NULL,  -- 阵亡泛红强度
  track_range               FLOAT DEFAULT NULL,  -- 追踪范围（敌方 AI，像素）
  attack_release_margin     FLOAT DEFAULT NULL,  -- 停火迟滞带（像素）
  track_release_margin      FLOAT DEFAULT NULL  -- 放弃追踪迟滞带（像素）
);

DROP TABLE IF EXISTS player_heavy;
CREATE TABLE player_heavy (  -- heavy_tank
  unit_id                   VARCHAR(32) NOT NULL PRIMARY KEY,  -- 单位唯一标识
  unit_name                 VARCHAR(32) DEFAULT NULL,  -- 显示名
  cost                      INT NOT NULL DEFAULT 0,  -- 招募资源消耗（点数）
  build_time                FLOAT NOT NULL DEFAULT 0,  -- 训练耗时（秒）
  max_hp                    INT NOT NULL DEFAULT 1,  -- 最大生命值
  armor                     INT NOT NULL DEFAULT 0,  -- 固定减伤护甲
  move_speed                FLOAT NOT NULL DEFAULT 0,  -- 移动速度（像素/秒）
  action_range              FLOAT NOT NULL DEFAULT 0,  -- 攻击/作用距离（像素）
  action_value              INT NOT NULL DEFAULT 0,  -- 作用数值（正为伤害/治疗）
  action_cd                 FLOAT NOT NULL DEFAULT 0,  -- 技能冷却/攻击间隔（秒）
  target_type               INT NOT NULL DEFAULT 0 CHECK (target_type IN (0, 1)),  -- 作用目标判定：0 = 敌方单位，1 = 我方单位（支援单位对我方回血用）
  armor_penetration         INT NOT NULL DEFAULT 0,  -- 破甲值：对拥有护甲的敌人能减去的护甲值
  -- ---- 以下为代码内使用的静态数值（自定字段名与类型）----
  squad_size                INT DEFAULT 1,  -- 编队人数：多人独立碰撞体、合并为一个基本单位
  roster                    VARCHAR(128) DEFAULT NULL,  -- 编队花名册（逗号分隔）
  character_scale           FLOAT DEFAULT NULL,  -- 角色渲染缩放
  collision_radius          FLOAT DEFAULT NULL,  -- 单位移动碰撞体半径
  member_collision_radius   FLOAT DEFAULT NULL,  -- 单名队员的圆形判定体半径
  formation_side            FLOAT DEFAULT NULL,  -- 三角阵型边长
  red_zone_clearance        FLOAT DEFAULT NULL,  -- 与红色屏蔽区边缘保持的安全距离
  member_separation         FLOAT DEFAULT NULL,  -- 队员之间的最小间距
  member_enemy_separation   FLOAT DEFAULT NULL,  -- 队员与敌方单位之间的隔离距离
  regen_delay               INT DEFAULT NULL,  -- 距上次受击多久开始回血（毫秒）
  regen_per_second          FLOAT DEFAULT NULL,  -- 每秒恢复的最大生命值比例
  detonate_delay            INT DEFAULT NULL,  -- 血条耗尽到自爆/引爆的延迟（毫秒）
  detonate_radius           FLOAT DEFAULT NULL,  -- 自爆半径（像素）
  detonate_damage           FLOAT DEFAULT NULL,  -- 爆心伤害
  detonate_damage_falloff   FLOAT DEFAULT NULL,  -- 每档伤害递减比例
  detonate_falloff_step     FLOAT DEFAULT NULL,  -- 伤害递减档距（像素）
  charge_speed              FLOAT DEFAULT NULL,  -- 阵亡冲锋速度（像素/秒）
  charge_trigger_distance   FLOAT DEFAULT NULL,  -- 贴上该距离立即自爆（像素）
  death_tint_duration       INT DEFAULT NULL,  -- 阵亡泛红时长（毫秒）
  death_tint_strength       FLOAT DEFAULT NULL,  -- 阵亡泛红强度
  track_range               FLOAT DEFAULT NULL,  -- 追踪范围（敌方 AI，像素）
  attack_release_margin     FLOAT DEFAULT NULL,  -- 停火迟滞带（像素）
  track_release_margin      FLOAT DEFAULT NULL  -- 放弃追踪迟滞带（像素）
);

DROP TABLE IF EXISTS player_support;
CREATE TABLE player_support (  -- medic（target_type = 1 为我方单位回血）
  unit_id                   VARCHAR(32) NOT NULL PRIMARY KEY,  -- 单位唯一标识
  unit_name                 VARCHAR(32) DEFAULT NULL,  -- 显示名
  cost                      INT NOT NULL DEFAULT 0,  -- 招募资源消耗（点数）
  build_time                FLOAT NOT NULL DEFAULT 0,  -- 训练耗时（秒）
  max_hp                    INT NOT NULL DEFAULT 1,  -- 最大生命值
  armor                     INT NOT NULL DEFAULT 0,  -- 固定减伤护甲
  move_speed                FLOAT NOT NULL DEFAULT 0,  -- 移动速度（像素/秒）
  action_range              FLOAT NOT NULL DEFAULT 0,  -- 攻击/作用距离（像素）
  action_value              INT NOT NULL DEFAULT 0,  -- 作用数值（正为伤害/治疗）
  action_cd                 FLOAT NOT NULL DEFAULT 0,  -- 技能冷却/攻击间隔（秒）
  target_type               INT NOT NULL DEFAULT 0 CHECK (target_type IN (0, 1)),  -- 作用目标判定：0 = 敌方单位，1 = 我方单位（支援单位对我方回血用）
  armor_penetration         INT NOT NULL DEFAULT 0,  -- 破甲值：对拥有护甲的敌人能减去的护甲值
  -- ---- 以下为代码内使用的静态数值（自定字段名与类型）----
  squad_size                INT DEFAULT 1,  -- 编队人数：多人独立碰撞体、合并为一个基本单位
  roster                    VARCHAR(128) DEFAULT NULL,  -- 编队花名册（逗号分隔）
  character_scale           FLOAT DEFAULT NULL,  -- 角色渲染缩放
  collision_radius          FLOAT DEFAULT NULL,  -- 单位移动碰撞体半径
  member_collision_radius   FLOAT DEFAULT NULL,  -- 单名队员的圆形判定体半径
  formation_side            FLOAT DEFAULT NULL,  -- 三角阵型边长
  red_zone_clearance        FLOAT DEFAULT NULL,  -- 与红色屏蔽区边缘保持的安全距离
  member_separation         FLOAT DEFAULT NULL,  -- 队员之间的最小间距
  member_enemy_separation   FLOAT DEFAULT NULL,  -- 队员与敌方单位之间的隔离距离
  regen_delay               INT DEFAULT NULL,  -- 距上次受击多久开始回血（毫秒）
  regen_per_second          FLOAT DEFAULT NULL,  -- 每秒恢复的最大生命值比例
  detonate_delay            INT DEFAULT NULL,  -- 血条耗尽到自爆/引爆的延迟（毫秒）
  detonate_radius           FLOAT DEFAULT NULL,  -- 自爆半径（像素）
  detonate_damage           FLOAT DEFAULT NULL,  -- 爆心伤害
  detonate_damage_falloff   FLOAT DEFAULT NULL,  -- 每档伤害递减比例
  detonate_falloff_step     FLOAT DEFAULT NULL,  -- 伤害递减档距（像素）
  charge_speed              FLOAT DEFAULT NULL,  -- 阵亡冲锋速度（像素/秒）
  charge_trigger_distance   FLOAT DEFAULT NULL,  -- 贴上该距离立即自爆（像素）
  death_tint_duration       INT DEFAULT NULL,  -- 阵亡泛红时长（毫秒）
  death_tint_strength       FLOAT DEFAULT NULL,  -- 阵亡泛红强度
  track_range               FLOAT DEFAULT NULL,  -- 追踪范围（敌方 AI，像素）
  attack_release_margin     FLOAT DEFAULT NULL,  -- 停火迟滞带（像素）
  track_release_margin      FLOAT DEFAULT NULL  -- 放弃追踪迟滞带（像素）
);

DROP TABLE IF EXISTS player_merc;
CREATE TABLE player_merc (  -- inf_temp（战场雇佣 / 战场支援单位）
  unit_id                   VARCHAR(32) NOT NULL PRIMARY KEY,  -- 单位唯一标识
  unit_name                 VARCHAR(32) DEFAULT NULL,  -- 显示名
  cost                      INT NOT NULL DEFAULT 0,  -- 招募资源消耗（点数）
  build_time                FLOAT NOT NULL DEFAULT 0,  -- 训练耗时（秒）
  max_hp                    INT NOT NULL DEFAULT 1,  -- 最大生命值
  armor                     INT NOT NULL DEFAULT 0,  -- 固定减伤护甲
  move_speed                FLOAT NOT NULL DEFAULT 0,  -- 移动速度（像素/秒）
  action_range              FLOAT NOT NULL DEFAULT 0,  -- 攻击/作用距离（像素）
  action_value              INT NOT NULL DEFAULT 0,  -- 作用数值（正为伤害/治疗）
  action_cd                 FLOAT NOT NULL DEFAULT 0,  -- 技能冷却/攻击间隔（秒）
  target_type               INT NOT NULL DEFAULT 0 CHECK (target_type IN (0, 1)),  -- 作用目标判定：0 = 敌方单位，1 = 我方单位（支援单位对我方回血用）
  armor_penetration         INT NOT NULL DEFAULT 0,  -- 破甲值：对拥有护甲的敌人能减去的护甲值
  -- ---- 以下为代码内使用的静态数值（自定字段名与类型）----
  squad_size                INT DEFAULT 1,  -- 编队人数：多人独立碰撞体、合并为一个基本单位
  roster                    VARCHAR(128) DEFAULT NULL,  -- 编队花名册（逗号分隔）
  character_scale           FLOAT DEFAULT NULL,  -- 角色渲染缩放
  collision_radius          FLOAT DEFAULT NULL,  -- 单位移动碰撞体半径
  member_collision_radius   FLOAT DEFAULT NULL,  -- 单名队员的圆形判定体半径
  formation_side            FLOAT DEFAULT NULL,  -- 三角阵型边长
  red_zone_clearance        FLOAT DEFAULT NULL,  -- 与红色屏蔽区边缘保持的安全距离
  member_separation         FLOAT DEFAULT NULL,  -- 队员之间的最小间距
  member_enemy_separation   FLOAT DEFAULT NULL,  -- 队员与敌方单位之间的隔离距离
  regen_delay               INT DEFAULT NULL,  -- 距上次受击多久开始回血（毫秒）
  regen_per_second          FLOAT DEFAULT NULL,  -- 每秒恢复的最大生命值比例
  detonate_delay            INT DEFAULT NULL,  -- 血条耗尽到自爆/引爆的延迟（毫秒）
  detonate_radius           FLOAT DEFAULT NULL,  -- 自爆半径（像素）
  detonate_damage           FLOAT DEFAULT NULL,  -- 爆心伤害
  detonate_damage_falloff   FLOAT DEFAULT NULL,  -- 每档伤害递减比例
  detonate_falloff_step     FLOAT DEFAULT NULL,  -- 伤害递减档距（像素）
  charge_speed              FLOAT DEFAULT NULL,  -- 阵亡冲锋速度（像素/秒）
  charge_trigger_distance   FLOAT DEFAULT NULL,  -- 贴上该距离立即自爆（像素）
  death_tint_duration       INT DEFAULT NULL,  -- 阵亡泛红时长（毫秒）
  death_tint_strength       FLOAT DEFAULT NULL,  -- 阵亡泛红强度
  track_range               FLOAT DEFAULT NULL,  -- 追踪范围（敌方 AI，像素）
  attack_release_margin     FLOAT DEFAULT NULL,  -- 停火迟滞带（像素）
  track_release_margin      FLOAT DEFAULT NULL  -- 放弃追踪迟滞带（像素）
);

DROP TABLE IF EXISTS enemy_infantry;
CREATE TABLE enemy_infantry (  -- Vespid（现役单位）
  unit_id                   VARCHAR(32) NOT NULL PRIMARY KEY,  -- 单位唯一标识
  unit_name                 VARCHAR(32) DEFAULT NULL,  -- 显示名
  cost                      INT NOT NULL DEFAULT 0,  -- 招募资源消耗（点数）
  build_time                FLOAT NOT NULL DEFAULT 0,  -- 训练耗时（秒）
  max_hp                    INT NOT NULL DEFAULT 1,  -- 最大生命值
  armor                     INT NOT NULL DEFAULT 0,  -- 固定减伤护甲
  move_speed                FLOAT NOT NULL DEFAULT 0,  -- 移动速度（像素/秒）
  action_range              FLOAT NOT NULL DEFAULT 0,  -- 攻击/作用距离（像素）
  action_value              INT NOT NULL DEFAULT 0,  -- 作用数值（正为伤害/治疗）
  action_cd                 FLOAT NOT NULL DEFAULT 0,  -- 技能冷却/攻击间隔（秒）
  target_type               INT NOT NULL DEFAULT 0 CHECK (target_type IN (0, 1)),  -- 作用目标判定：0 = 敌方单位，1 = 我方单位（支援单位对我方回血用）
  armor_penetration         INT NOT NULL DEFAULT 0,  -- 破甲值：对拥有护甲的敌人能减去的护甲值
  -- ---- 以下为代码内使用的静态数值（自定字段名与类型）----
  squad_size                INT DEFAULT 1,  -- 编队人数：多人独立碰撞体、合并为一个基本单位
  roster                    VARCHAR(128) DEFAULT NULL,  -- 编队花名册（逗号分隔）
  character_scale           FLOAT DEFAULT NULL,  -- 角色渲染缩放
  collision_radius          FLOAT DEFAULT NULL,  -- 单位移动碰撞体半径
  member_collision_radius   FLOAT DEFAULT NULL,  -- 单名队员的圆形判定体半径
  formation_side            FLOAT DEFAULT NULL,  -- 三角阵型边长
  red_zone_clearance        FLOAT DEFAULT NULL,  -- 与红色屏蔽区边缘保持的安全距离
  member_separation         FLOAT DEFAULT NULL,  -- 队员之间的最小间距
  member_enemy_separation   FLOAT DEFAULT NULL,  -- 队员与敌方单位之间的隔离距离
  regen_delay               INT DEFAULT NULL,  -- 距上次受击多久开始回血（毫秒）
  regen_per_second          FLOAT DEFAULT NULL,  -- 每秒恢复的最大生命值比例
  detonate_delay            INT DEFAULT NULL,  -- 血条耗尽到自爆/引爆的延迟（毫秒）
  detonate_radius           FLOAT DEFAULT NULL,  -- 自爆半径（像素）
  detonate_damage           FLOAT DEFAULT NULL,  -- 爆心伤害
  detonate_damage_falloff   FLOAT DEFAULT NULL,  -- 每档伤害递减比例
  detonate_falloff_step     FLOAT DEFAULT NULL,  -- 伤害递减档距（像素）
  charge_speed              FLOAT DEFAULT NULL,  -- 阵亡冲锋速度（像素/秒）
  charge_trigger_distance   FLOAT DEFAULT NULL,  -- 贴上该距离立即自爆（像素）
  death_tint_duration       INT DEFAULT NULL,  -- 阵亡泛红时长（毫秒）
  death_tint_strength       FLOAT DEFAULT NULL,  -- 阵亡泛红强度
  track_range               FLOAT DEFAULT NULL,  -- 追踪范围（敌方 AI，像素）
  attack_release_margin     FLOAT DEFAULT NULL,  -- 停火迟滞带（像素）
  track_release_margin      FLOAT DEFAULT NULL  -- 放弃追踪迟滞带（像素）
);

DROP TABLE IF EXISTS enemy_heavy;
CREATE TABLE enemy_heavy (  -- 敌方重甲，id 待定
  unit_id                   VARCHAR(32) NOT NULL PRIMARY KEY,  -- 单位唯一标识
  unit_name                 VARCHAR(32) DEFAULT NULL,  -- 显示名
  cost                      INT NOT NULL DEFAULT 0,  -- 招募资源消耗（点数）
  build_time                FLOAT NOT NULL DEFAULT 0,  -- 训练耗时（秒）
  max_hp                    INT NOT NULL DEFAULT 1,  -- 最大生命值
  armor                     INT NOT NULL DEFAULT 0,  -- 固定减伤护甲
  move_speed                FLOAT NOT NULL DEFAULT 0,  -- 移动速度（像素/秒）
  action_range              FLOAT NOT NULL DEFAULT 0,  -- 攻击/作用距离（像素）
  action_value              INT NOT NULL DEFAULT 0,  -- 作用数值（正为伤害/治疗）
  action_cd                 FLOAT NOT NULL DEFAULT 0,  -- 技能冷却/攻击间隔（秒）
  target_type               INT NOT NULL DEFAULT 0 CHECK (target_type IN (0, 1)),  -- 作用目标判定：0 = 敌方单位，1 = 我方单位（支援单位对我方回血用）
  armor_penetration         INT NOT NULL DEFAULT 0,  -- 破甲值：对拥有护甲的敌人能减去的护甲值
  -- ---- 以下为代码内使用的静态数值（自定字段名与类型）----
  squad_size                INT DEFAULT 1,  -- 编队人数：多人独立碰撞体、合并为一个基本单位
  roster                    VARCHAR(128) DEFAULT NULL,  -- 编队花名册（逗号分隔）
  character_scale           FLOAT DEFAULT NULL,  -- 角色渲染缩放
  collision_radius          FLOAT DEFAULT NULL,  -- 单位移动碰撞体半径
  member_collision_radius   FLOAT DEFAULT NULL,  -- 单名队员的圆形判定体半径
  formation_side            FLOAT DEFAULT NULL,  -- 三角阵型边长
  red_zone_clearance        FLOAT DEFAULT NULL,  -- 与红色屏蔽区边缘保持的安全距离
  member_separation         FLOAT DEFAULT NULL,  -- 队员之间的最小间距
  member_enemy_separation   FLOAT DEFAULT NULL,  -- 队员与敌方单位之间的隔离距离
  regen_delay               INT DEFAULT NULL,  -- 距上次受击多久开始回血（毫秒）
  regen_per_second          FLOAT DEFAULT NULL,  -- 每秒恢复的最大生命值比例
  detonate_delay            INT DEFAULT NULL,  -- 血条耗尽到自爆/引爆的延迟（毫秒）
  detonate_radius           FLOAT DEFAULT NULL,  -- 自爆半径（像素）
  detonate_damage           FLOAT DEFAULT NULL,  -- 爆心伤害
  detonate_damage_falloff   FLOAT DEFAULT NULL,  -- 每档伤害递减比例
  detonate_falloff_step     FLOAT DEFAULT NULL,  -- 伤害递减档距（像素）
  charge_speed              FLOAT DEFAULT NULL,  -- 阵亡冲锋速度（像素/秒）
  charge_trigger_distance   FLOAT DEFAULT NULL,  -- 贴上该距离立即自爆（像素）
  death_tint_duration       INT DEFAULT NULL,  -- 阵亡泛红时长（毫秒）
  death_tint_strength       FLOAT DEFAULT NULL,  -- 阵亡泛红强度
  track_range               FLOAT DEFAULT NULL,  -- 追踪范围（敌方 AI，像素）
  attack_release_margin     FLOAT DEFAULT NULL,  -- 停火迟滞带（像素）
  track_release_margin      FLOAT DEFAULT NULL  -- 放弃追踪迟滞带（像素）
);

DROP TABLE IF EXISTS enemy_support;
CREATE TABLE enemy_support (  -- 敌方支援，id 待定
  unit_id                   VARCHAR(32) NOT NULL PRIMARY KEY,  -- 单位唯一标识
  unit_name                 VARCHAR(32) DEFAULT NULL,  -- 显示名
  cost                      INT NOT NULL DEFAULT 0,  -- 招募资源消耗（点数）
  build_time                FLOAT NOT NULL DEFAULT 0,  -- 训练耗时（秒）
  max_hp                    INT NOT NULL DEFAULT 1,  -- 最大生命值
  armor                     INT NOT NULL DEFAULT 0,  -- 固定减伤护甲
  move_speed                FLOAT NOT NULL DEFAULT 0,  -- 移动速度（像素/秒）
  action_range              FLOAT NOT NULL DEFAULT 0,  -- 攻击/作用距离（像素）
  action_value              INT NOT NULL DEFAULT 0,  -- 作用数值（正为伤害/治疗）
  action_cd                 FLOAT NOT NULL DEFAULT 0,  -- 技能冷却/攻击间隔（秒）
  target_type               INT NOT NULL DEFAULT 0 CHECK (target_type IN (0, 1)),  -- 作用目标判定：0 = 敌方单位，1 = 我方单位（支援单位对我方回血用）
  armor_penetration         INT NOT NULL DEFAULT 0,  -- 破甲值：对拥有护甲的敌人能减去的护甲值
  -- ---- 以下为代码内使用的静态数值（自定字段名与类型）----
  squad_size                INT DEFAULT 1,  -- 编队人数：多人独立碰撞体、合并为一个基本单位
  roster                    VARCHAR(128) DEFAULT NULL,  -- 编队花名册（逗号分隔）
  character_scale           FLOAT DEFAULT NULL,  -- 角色渲染缩放
  collision_radius          FLOAT DEFAULT NULL,  -- 单位移动碰撞体半径
  member_collision_radius   FLOAT DEFAULT NULL,  -- 单名队员的圆形判定体半径
  formation_side            FLOAT DEFAULT NULL,  -- 三角阵型边长
  red_zone_clearance        FLOAT DEFAULT NULL,  -- 与红色屏蔽区边缘保持的安全距离
  member_separation         FLOAT DEFAULT NULL,  -- 队员之间的最小间距
  member_enemy_separation   FLOAT DEFAULT NULL,  -- 队员与敌方单位之间的隔离距离
  regen_delay               INT DEFAULT NULL,  -- 距上次受击多久开始回血（毫秒）
  regen_per_second          FLOAT DEFAULT NULL,  -- 每秒恢复的最大生命值比例
  detonate_delay            INT DEFAULT NULL,  -- 血条耗尽到自爆/引爆的延迟（毫秒）
  detonate_radius           FLOAT DEFAULT NULL,  -- 自爆半径（像素）
  detonate_damage           FLOAT DEFAULT NULL,  -- 爆心伤害
  detonate_damage_falloff   FLOAT DEFAULT NULL,  -- 每档伤害递减比例
  detonate_falloff_step     FLOAT DEFAULT NULL,  -- 伤害递减档距（像素）
  charge_speed              FLOAT DEFAULT NULL,  -- 阵亡冲锋速度（像素/秒）
  charge_trigger_distance   FLOAT DEFAULT NULL,  -- 贴上该距离立即自爆（像素）
  death_tint_duration       INT DEFAULT NULL,  -- 阵亡泛红时长（毫秒）
  death_tint_strength       FLOAT DEFAULT NULL,  -- 阵亡泛红强度
  track_range               FLOAT DEFAULT NULL,  -- 追踪范围（敌方 AI，像素）
  attack_release_margin     FLOAT DEFAULT NULL,  -- 停火迟滞带（像素）
  track_release_margin      FLOAT DEFAULT NULL  -- 放弃追踪迟滞带（像素）
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
  track_release_margin
) VALUES (
  'JF',
  'JF',
  40,
  30,
  30,
  8,
  100,
  250,
  3,
  0.65,
  0,
  8,
  3,
  'Jiangyu,Qiongjiu,Daiyan',
  0.30,
  16,
  9,
  30,
  10,
  10,
  20,
  5000,
  0.05,
  5000,
  40,
  20,
  0.2,
  10,
  130,
  20,
  900,
  0.25,
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
  track_release_margin
) VALUES (
  'Vespid',
  'Vespid',
  0,
  0,
  40,
  8,
  80,
  100,
  2,
  1.1,
  0,
  8,
  1,
  'Vespid',
  0.145,
  11,
  NULL,
  NULL,
  NULL,
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
  160,
  12,
  16
);

-- ----------------------------------------------------------------------------
-- 示例查询
-- ----------------------------------------------------------------------------
-- 查看我方步兵所有字段：SELECT * FROM player_infantry;
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

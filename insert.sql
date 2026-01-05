CREATE TABLE `sentrix_restaurant` (
	`identifier` VARCHAR(60) NOT NULL COLLATE 'utf8mb4_uca1400_ai_ci',
	`xp` INT(11) NOT NULL DEFAULT '0',
	PRIMARY KEY (`identifier`) USING BTREE
)
ENGINE=InnoDB
;

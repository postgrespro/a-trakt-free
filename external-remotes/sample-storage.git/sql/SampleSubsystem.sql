CREATE TABLE projects (
    project_name varchar PRIMARY KEY
);

CREATE TABLE branches (
    project_name varchar NOT NULL REFERENCES projects (project_name) MATCH FULL ON UPDATE CASCADE ON DELETE CASCADE,
    branch_name varchar,
    PRIMARY KEY (project_name, branch_name)
);

CREATE TABLE trakts (
    project_name varchar NOT NULL REFERENCES projects (project_name) MATCH FULL ON UPDATE CASCADE ON DELETE CASCADE,
    trakt_name varchar PRIMARY KEY
);

CREATE TABLE targets (
    project_name varchar NOT NULL REFERENCES projects (project_name) MATCH FULL ON UPDATE CASCADE ON DELETE CASCADE,
    trakt_name varchar NOT NULL REFERENCES trakts (trakt_name) ON UPDATE CASCADE ON DELETE CASCADE,
    target_name varchar,
    PRIMARY KEY (project_name, trakt_name, target_name)
);

CREATE TABLE certifications (
    certification_name varchar NOT NULL PRIMARY KEY,
    certification_date timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE samples (
    project_name varchar NOT NULL, -- целостность обеспечивается за счет участия в более сложных внешних индексах
    certification_name varchar NOT NULL REFERENCES certifications(certification_name) MATCH FULL ON UPDATE CASCADE ON DELETE CASCADE,
    branch_name varchar NOT NULL,
    trakt_name varchar NOT NULL,
    target_name varchar NOT NULL,
    sample_name varchar NOT NULL,
    sample_file bytea NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    FOREIGN KEY  (project_name, trakt_name, target_name) REFERENCES targets(project_name, trakt_name, target_name) MATCH FULL ON UPDATE CASCADE ON DELETE CASCADE,
    FOREIGN KEY  (project_name, branch_name) REFERENCES branches(project_name, branch_name) MATCH FULL ON UPDATE CASCADE ON DELETE CASCADE,
    PRIMARY KEY (project_name, certification_name, branch_name, trakt_name, target_name, sample_name)
);

CREATE TABLE schema (
  version NUMERIC NOT NULL
);

INSERT INTO schema VALUES (1.0);

-- Заполняем справочники


INSERT INTO branches (project_name, branch_name) VALUES
('postgrespro', 'NONE'),  -- Специальная несуществующая ветка для начальных наборов сэмплов


INSERT INTO certifications (certification_name, certification_date) VALUES
('initial_samples', '2000-01-01');
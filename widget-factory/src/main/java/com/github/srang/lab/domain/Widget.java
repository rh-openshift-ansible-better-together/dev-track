package com.github.srang.lab.domain;

import lombok.Builder;
import lombok.Data;

import javax.persistence.Entity;
import javax.persistence.GeneratedValue;
import javax.persistence.GenerationType;
import javax.persistence.Id;

@Entity
@Data
public class Widget {
    @Id
    @GeneratedValue(strategy = GenerationType.AUTO)
    private Long id;
    private String label;
    private String version;
    private String description;

    @java.beans.ConstructorProperties({"label", "version", "description"})
    @Builder
    public Widget(String label, String version, String description) {
        this.label = label;
        this.version = version;
        this.description = description;
    }
}

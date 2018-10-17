package com.github.srang.lab.domain.repository;

import com.github.srang.lab.domain.Widget;
import org.springframework.data.repository.CrudRepository;
import org.springframework.stereotype.Component;

import java.util.List;

public interface WidgetRepository extends CrudRepository<Widget, Long> {
    List<Widget> findByLabel(String label);
}

package com.github.srang.lab.web;

import com.github.srang.lab.domain.Widget;
import org.springframework.data.repository.PagingAndSortingRepository;
import org.springframework.data.rest.core.annotation.RepositoryRestResource;

@RepositoryRestResource(collectionResourceRel = "widgets", path = "widgets")
public interface WidgetDataController extends PagingAndSortingRepository<Widget, Long> {
}

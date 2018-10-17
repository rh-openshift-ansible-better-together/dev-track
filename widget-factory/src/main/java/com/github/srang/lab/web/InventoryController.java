package com.github.srang.lab.web;

import com.github.srang.lab.domain.Widget;
import com.github.srang.lab.domain.repository.WidgetRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.MediaType;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/inventory")
public class InventoryController {

    private final WidgetRepository widgetRepository;

    @Autowired
    public InventoryController(WidgetRepository widgetRepository) {
        this.widgetRepository = widgetRepository;
    }

    @GetMapping(value = "/widgets", produces = MediaType.APPLICATION_JSON_VALUE)
    @ResponseBody
    @Transactional(readOnly = true)
    public Iterable<Widget> getInventory(@RequestParam(required = false) String label) {
        if (label != null) {
            return widgetRepository.findByLabel(label);
        } else {
            return widgetRepository.findAll();
        }
    }
}

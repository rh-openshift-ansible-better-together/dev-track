package com.github.srang.lab;

import com.github.srang.lab.domain.Widget;
import com.github.srang.lab.domain.repository.WidgetRepository;
import lombok.extern.java.Log;
import org.springframework.boot.CommandLineRunner;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.context.annotation.Bean;

@Log
@SpringBootApplication
public class DemoApplication {
    public static void main(String[] args) {
        SpringApplication.run(DemoApplication.class, args);
    }

    @Bean
    public CommandLineRunner loadData(WidgetRepository repository) {
        return (args) -> {
            // save a couple of widgets
            repository.save(Widget.builder()
                    .label("THNG01B")
                    .version("V1")
                    .description("Thingamajig Version 1 - Blue")
                    .build());
            repository.save(Widget.builder()
                    .label("THNG01R")
                    .version("V1")
                    .description("Thingamajig Version 1 - Red")
                    .build());
            repository.save(Widget.builder()
                    .label("THNG02B")
                    .version("V2")
                    .description("Thingamajig Version 2 - Blue")
                    .build());
            repository.save(Widget.builder()
                    .label("THNG02R")
                    .version("V2")
                    .description("Thingamajig Version 2 - Red")
                    .build());
            repository.save(Widget.builder()
                    .label("WTST00G")
                    .version("BETA")
                    .description("Whatsit Beta - Green")
                    .build());
        };
    }
}

source("0_packages.R")


if(!file.exists("hrs_surv_ind.rds") | !file.exists("hrs_surv_dep.rds")){
  hrs_full <- import("hrs_full_analytic.rds") 
  
  #=Approach #1: time-on-study as time-scale)====================================
  
  # #make survival model recodes (time-on-study approach)
  # hrs_surv <- hrs_full %>% 
  #   mutate(age_at_start = firstiw-birthyr,
  #          study_time = year-firstiw) %>% 
  #   group_by(hhidpn, cog_2cat_num) %>% 
  #   mutate(cog_first = min(study_time)) %>%
  #   group_by(hhidpn) %>% 
  #   mutate(cog_ever = max(cog_2cat_num),
  #          cog_surv_time = ifelse(cog_ever>0, max(cog_first), max(study_time))) %>% 
  #   ungroup() 
  # 
  # #time-independent 
  # hrs_surv_ind <- hrs_surv %>% 
  #   distinct(hhidpn, .keep_all=TRUE) %>% #removed 48,396 rows (87%), 6,949 rows remaining
  #   select(-c(year, stroke_ever, smoke_ever, age, cog_2cat, cog_2cat_num, cogfunction, edu_yrs)) %>% 
  #   filter(cog_surv_time>0) #removed 168 rows (2%), 6,781 rows remaining
  # 
  # #format time-independent variables
  # hrs_surv_ind_fmt <- tmerge(data1 = hrs_surv_ind,
  #                            data2 = hrs_surv_ind,
  #                            id=hhidpn,
  #                            event=event(cog_surv_time, cog_ever))
  # 
  # #time-dependent
  # hrs_surv_dep <- hrs_surv %>% 
  #   distinct(hhidpn, study_time, stroke_ever, smoke_ever, .keep_all=FALSE)
  # 
  # #merge
  # hrs_surv_final <- tmerge(data1 = hrs_surv_ind_fmt,
  #                          data2 = hrs_surv_dep,
  #                          id=hhidpn,
  #                          stroke=tdc(study_time, stroke_ever),
  #                          smoke=tdc(study_time, smoke_ever))
  
  
  #=Approach #2: age as time-scale approach)=====================================
  
  #make survival model recodes (age as time-scale approach)
  hrs_surv <- hrs_full %>% 
    group_by(hhidpn) %>% 
    fill(dod_yr, .direction="updown") %>% 
    ungroup() %>% 
    mutate(study_age = year-birthyr,
           firstiw_age = firstiw-birthyr,
           dod_age = as_numeric(dod_yr)-birthyr) %>% 
    group_by(hhidpn) %>% 
    mutate(cog_first = ifelse(cog_2cat_num==1, study_age, NA),
           cog_first = pmin(cog_first)) %>%
    fill(cog_first, .direction="updown") %>% 
    mutate(cog_ever = max(cog_2cat_num),
           cog_surv_age = ifelse(cog_ever>0, cog_first, max(study_age))) %>% 
    ungroup() 
    # filter(age>=50) #removed 2,032 rows (4%), 53,313 rows remaining
  
  
  #time-independent 
  hrs_surv_ind <- hrs_surv %>% 
    distinct(hhidpn, .keep_all=TRUE) %>% #removed 48,396 rows (87%), 6,949 rows remaining
    select(-c(year, stroke_ever, smoke_ever, age, cog_2cat, cog_2cat_num, cogfunction, edu_yrs)) %>% 
    filter(cog_surv_age>firstiw_age) #removed 279 rows (4%), 6,603 rows remaining
  
  #format time-independent variables
  hrs_surv_ind_fmt <- tmerge(data1 = hrs_surv_ind,
                             data2 = hrs_surv_ind,
                             id=hhidpn,
                             event=event(cog_surv_age, cog_ever))
  
  #time-dependent
  hrs_surv_dep <- hrs_surv %>% 
    distinct(hhidpn, study_age, .keep_all=TRUE) %>% 
    select(hhidpn, study_age, stroke_ever, smoke_ever)
  
  #merge
  hrs_surv_final <- tmerge(data1 = hrs_surv_ind_fmt,
                           data2 = hrs_surv_dep,
                           id=hhidpn,
                           stroke=tdc(study_age, stroke_ever),
                           smoke=tdc(study_age, smoke_ever)) %>% 
    filter(tstart>0) #removed 6,661 rows (14%), 42,015 rows remaining
  
  export(hrs_surv_final, "hrs_surv_dep.rds")
  export(hrs_surv_ind_fmt, "hrs_surv_ind.rds")
} else {
  
  hrs_surv_ind<- import("hrs_surv_ind.rds")
  hrs_surv_dep<- import("hrs_surv_dep.rds")
}

#=Fit and visualize basic survival curves======================================

#INCARCERATION
surv_ind_incar <- survfit(Surv(study_age, event) ~ incar_ever, data=hrs_surv_ind)

survplot1 <- ggsurvplot(surv_ind_incar,
                        conf.int = TRUE,
                        pval = TRUE, 
                        pval.method = TRUE,
                        risk.table = "nrisk_cumevents",
                        fontsize=6,
                        cumevents = TRUE,
                        xlim=c(50,100),
                        break.x.by=10,
                        # surv.median.line = "hv",
                        censor.shape=NA,
                        palette = c("darkblue", "darkred"),
                        cumcensor = TRUE) 

#median survival age================================#
closest<-function(var,val){
  var[which(abs(var-val)==min(abs(var-val)))] 
}

median_surv_nojail <- survplot1$data.survplot %>% 
  filter(incar_ever=="Not Incarcerated") %>% 
  filter(surv==closest(surv, .5)) %>% 
  pull(time)

median_surv_jail <- survplot1$data.survplot %>% 
  filter(incar_ever=="Incarcerated") %>% 
  filter(surv==closest(surv, .5)) %>% 
  pull(time)
#==================================================#


plot1 <- survplot1$plot +
  labs(y="Survival probability\n(no cognitive impairment)",
       x="Age") +
  theme(legend.title = element_text(size = 22, face = "bold"),
        legend.text = element_text(size = 22),
        legend.direction = "vertical",
        legend.position = c(.85, .85),
        axis.title.x.bottom = element_text(size=22, face = "bold"),
        axis.title.y.left = element_text(size=22, face = "bold", vjust = -15),
        axis.text.y.left = element_text(size = 18),
        axis.text.x.bottom = element_text(size=18)) +
  geom_segment(aes(x=45, xend=79, y=.5, yend=.5), linewidth=1, linetype="dashed") +
  geom_segment(aes(x=median_surv_nojail, xend=median_surv_nojail, y=0, yend=.5),  linewidth=1, linetype="dashed") +
  geom_segment(aes(x=median_surv_jail, xend=median_surv_jail, y=0, yend=.5),  linewidth=1, linetype="dashed") +
  scale_y_continuous(expand = c(0,0)) +
  annotate("text", x=60, y=.25, size=7, fontface="bold", label=expression(atop(textstyle("Log-rank"), paste(italic("p"), "<0.0001")))) +
  scale_fill_manual(name="Lifetime incarceration",
                    values = c("darkblue", "darkred"),
                    labels = c("Never-incarcerated", "Incarcerated")) +
  scale_color_manual(name="Lifetime incarceration",
                     values = c("darkblue", "darkred"),
                    labels = c("Never-incarcerated", "Incarcerated")) 
plot1

tab1 <- survplot1$table +
  labs(y="",
       x="") +
  scale_y_discrete(labels=c("Incarcerated", "Never-\nincarcerated")) +
  theme(axis.text.y.left = element_text(size = 22, face = "bold", hjust = .5),
        plot.title       = element_text(size = 22, face = "bold"),
        axis.text.x = element_blank(),
        axis.ticks = element_blank(),
        axis.line.y.left = element_line(colour = NA),
        panel.background = element_rect(color = "black", linewidth = 1))


  
survplot_incar <- plot1 / tab1 + plot_layout(heights = c(3,1)) 
survplot_incar
ggsave("../output/figures/survplot_incar.png", survplot_incar, width = 15, height = 8)


#APOE-4
surv_ind_apoe4 <- survfit(Surv(study_age, event) ~ apoe_info99_4ct, data=hrs_surv_ind)

survplot2 <- ggsurvplot(surv_ind_apoe4,
                        conf.int = TRUE,
                        pval = TRUE, 
                        pval.method = TRUE,
                        risk.table = "nrisk_cumevents",
                        fontsize=6,
                        cumevents = TRUE,
                        xlim=c(50,100),
                        break.x.by=10,
                        # surv.median.line = "hv",
                        censor.shape=NA,
                        palette = c("darkblue", "darkslateblue", "darkred"),
                        cumcensor = TRUE) 

#median survival age================================#
closest<-function(var,val){
  var[which(abs(var-val)==min(abs(var-val)))] 
}

median_surv_zero <- survplot2$data.survplot %>% 
  filter(apoe_info99_4ct=="zero copies") %>% 
  filter(surv==closest(surv, .5)) %>% 
  pull(time)

median_surv_one <- survplot2$data.survplot %>% 
  filter(apoe_info99_4ct=="one copy") %>% 
  filter(surv==closest(surv, .5)) %>% 
  pull(time)

median_surv_two <- survplot2$data.survplot %>% 
  filter(apoe_info99_4ct=="two copies") %>% 
  filter(surv==closest(surv, .5)) %>% 
  pull(time)
#==================================================#

plot2 <- survplot2$plot +
  labs(y="Survival probability\n(no cognitive impairment)",
       x="Age") +
  theme(legend.title = element_text(size = 22, face = "bold"),
        legend.text = element_text(size = 22),
        legend.direction = "vertical",
        legend.position = c(.85, .85),
        axis.title.x.bottom = element_text(size=22, face = "bold"),
        axis.title.y.left = element_text(size=22, face = "bold", vjust = -15),
        axis.text.y.left   = element_text(size = 18),
        axis.text.x.bottom = element_text(size = 18)) +
  geom_segment(aes(x=45, xend=79, y=.5, yend=.5), linewidth=1, linetype="dashed") +
  geom_segment(aes(x=median_surv_zero, xend=median_surv_zero, y=0, yend=.5),  linewidth=1, linetype="dashed") +
  geom_segment(aes(x=median_surv_one, xend=median_surv_one, y=0, yend=.5),  linewidth=1, linetype="dashed") +
  geom_segment(aes(x=median_surv_two, xend=median_surv_two, y=0, yend=.5),  linewidth=1, linetype="dashed") +
  scale_y_continuous(expand = c(0,0)) +
  annotate("text", x=60, y=.25, size=7, fontface="bold", label=expression(atop(textstyle("Log-rank"), paste(italic("p"), "<0.0001")))) +
  scale_fill_manual(name=paste0("APOE-", "\u03b5", "4\nAllele Count"),
                    values = c("darkblue", "darkslateblue", "darkred"),
                    labels = c("Zero", "One", "Two")) +
  scale_color_manual(name=paste0("APOE-", "\u03b5", "4\nAllele Count"),
                     values = c("darkblue",  "darkslateblue", "darkred"),
                     labels = c("Zero", "One", "Two"))
plot2

tab2 <- survplot2$table +
  labs(y="",
       x="") +
  scale_y_discrete(labels=c("Two", "One", "Zero")) +
  theme(axis.title.y.left = element_blank(),
        axis.text.y.left  = element_text(size = 22, face = "bold", hjust = .5),
        plot.title        = element_text(size = 22, face = "bold"),
        axis.text.x = element_blank(),
        axis.ticks = element_blank(),
        axis.line.y.left = element_line(colour = NA),
        panel.background = element_rect(color = "black", linewidth = 1))

survplot_apoe4 <- plot2 / tab2 + plot_layout(heights = c(3,1)) 
survplot_apoe4
ggsave("../output/figures/survplot_apoe4.png", survplot_apoe4, width = 15, height = 8)

#=Combine plots========================================#

# design1="
# AAACCC
# AAACCC
# AAACCC
# AAACCC
# AAACCC
# BBBDDD
# "
# 
# combined1 <- plot1 + tab1 + plot2 + tab2 + 
#   plot_layout(design = design1, tag_level = "new") + 
#   plot_annotation(tag_levels = "A", tag_suffix=".") &
#   theme(plot.tag = element_text(size = 24, face = "bold"))
# combined1
# ggsave("../output/figures/survplot_combined1.png", combined1, width = 28, height =10)

design2="
AAA
AAA
AAA
AAA
AAA
BBB
CCC
CCC
CCC
CCC
CCC
DDD"

combined2 <- plot1 + tab1 + plot2 + tab2 + 
  plot_layout(design = design2, tag_level = "new") + 
  plot_annotation(tag_levels = "A", tag_suffix=".") &
  theme(plot.tag = element_text(size = 24, face = "bold"))
# combined2
ggsave("../output/figures/survplot_combined2.png", combined2, width = 16, height =20)

#=Fit Cox model================================================================

#INCARCERATION
#time-dependent covariates
cox1 <- coxph(Surv(tstart, tstop, event) ~ incar_ever +
                 factor(sex) + factor(race_ethn) + factor(edu) + scale(social_origins) + strata(study) +
                 factor(smoke) + factor(stroke), data=hrs_surv_dep, id=hhidpn)
cox1_res <- tidy(cox1, exponentiate = TRUE) %>% mutate(model = "incar_ever")
cox1_res


#APOE4
#time-dependent covariates
cox2 <- coxph(Surv(tstart, tstop, event) ~ apoe_info99_4ct +
                 factor(sex) + factor(race_ethn) + factor(edu) + scale(social_origins) + strata(study) +
                 factor(smoke) + factor(stroke), data=hrs_surv_dep, id=hhidpn)
cox2_res <- tidy(cox2, exponentiate = TRUE) %>% mutate(model = "apoe_4")
cox2_res

#INCARCERATION + APOE4
#time-dependent covariates
cox3 <- coxph(Surv(tstart, tstop, event) ~ incar_ever + apoe_info99_4ct +
                factor(sex) + factor(race_ethn) + factor(edu) + scale(social_origins) + strata(study) +
                factor(smoke) + factor(stroke), data=hrs_surv_dep, id=hhidpn)
cox3_res <- tidy(cox3, exponentiate = TRUE) %>% mutate(model = "incar_apoe_4")
cox3_res

#INCARCERATION x APOE4
#time-dependent covariates
cox4 <- coxph(Surv(tstart, tstop, event) ~ incar_ever*apoe_info99_4ct +
                factor(sex) + factor(race_ethn) + factor(edu) + scale(social_origins) + strata(study) +
                factor(smoke) + factor(stroke), data=hrs_surv_dep, id=hhidpn)
cox4_res <- tidy(cox4, exponentiate = TRUE) %>% mutate(model = "incar_x_apoe_4")
cox4_res


# #=test of the proportionality assumption=====================================
# cox.zph(cox1)  %>% ggcoxzph()
# ggcoxdiagnostics(cox1)
# 
# cox.zph(cox2.0) %>% ggcoxzph()
# cox.zph(cox2.1) %>% ggcoxzph()
# ggcoxdiagnostics(cox2.1)
# 
# #time-dependent covariates 
# test = survfit(Surv(study_age, event) ~ incar_ever + 
#                 # factor(sex) + factor(race_ethn) + factor(edu) + scale(social_origins) + factor(study), data=hrs_surv_ind)
#                 factor(sex) + factor(race_ethn) + factor(edu) + scale(social_origins) + strata(study), data=hrs_surv_ind)
# 
# rms::survest(test, loglog=TRUE)

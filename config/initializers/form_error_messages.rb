# f.error_messages (replaces the unmaintained dynamic_form gem), styled by .errorExplanation in admin/flash_messages.scss
ActiveSupport.on_load(:action_view) do
  ActionView::Helpers::FormBuilder.class_eval do
    def error_messages
      return "" if object.nil? || object.errors.empty?
      count = object.errors.count
      @template.tag.div(id: "errorExplanation", class: "errorExplanation") do
        @template.tag.h2("#{@template.pluralize(count, "error")} prohibited this #{object_name.to_s.tr("_", " ")} from being saved") +
          @template.tag.ul(@template.safe_join(object.errors.full_messages.map { |msg| @template.tag.li(msg) }))
      end
    end
  end
end

## Examples

### Example 1: Accessible Form

```tsx
function AccessibleContactForm() {
  const [errors, setErrors] = useState<Record<string, string>>({});
  const [submitStatus, setSubmitStatus] = useState<'idle' | 'success' | 'error'>('idle');

  return (
    <form onSubmit={handleSubmit} noValidate>
      <h2 id="form-title">Contact Us</h2>
      <p id="form-description">Please fill out the form below to get in touch.</p>

      {/* Name */}
      <div className="form-group">
        <label htmlFor="name">
          Name <span aria-label="required">*</span>
        </label>
        <input
          type="text"
          id="name"
          name="name"
          required
          aria-required="true"
          aria-invalid={!!errors.name}
          aria-describedby={errors.name ? 'name-error' : undefined}
        />
        {errors.name && (
          <span id="name-error" role="alert" className="error">
            {errors.name}
          </span>
        )}
      </div>

      {/* Email */}
      <div className="form-group">
        <label htmlFor="email">
          Email <span aria-label="required">*</span>
        </label>
        <input
          type="email"
          id="email"
          name="email"
          required
          aria-required="true"
          aria-invalid={!!errors.email}
          aria-describedby={errors.email ? 'email-error' : 'email-hint'}
        />
        <span id="email-hint" className="hint">
          We'll never share your email.
        </span>
        {errors.email && (
          <span id="email-error" role="alert" className="error">
            {errors.email}
          </span>
        )}
      </div>

      {/* Submit button */}
      <button type="submit" disabled={submitStatus === 'loading'}>
        {submitStatus === 'loading' ? 'Submitting...' : 'Submit'}
      </button>

      {/* Success/failure messages */}
      {submitStatus === 'success' && (
        <div role="alert" aria-live="polite" className="success">
          ✅ Form submitted successfully!
        </div>
      )}

      {submitStatus === 'error' && (
        <div role="alert" aria-live="assertive" className="error">
          ⚠️ An error occurred. Please try again.
        </div>
      )}
    </form>
  );
}
```

### Example 2: Accessible Tab UI

```tsx
function AccessibleTabs({ tabs }: { tabs: { id: string; label: string; content: React.ReactNode }[] }) {
  const [activeTab, setActiveTab] = useState(0);

  const handleKeyDown = (e: React.KeyboardEvent, index: number) => {
    switch (e.key) {
      case 'ArrowRight':
        e.preventDefault();
        setActiveTab((index + 1) % tabs.length);
        break;
      case 'ArrowLeft':
        e.preventDefault();
        setActiveTab((index - 1 + tabs.length) % tabs.length);
        break;
      case 'Home':
        e.preventDefault();
        setActiveTab(0);
        break;
      case 'End':
        e.preventDefault();
        setActiveTab(tabs.length - 1);
        break;
    }
  };

  return (
    <div>
      {/* Tab List */}
      <div role="tablist" aria-label="Content sections">
        {tabs.map((tab, index) => (
          <button
            key={tab.id}
            role="tab"
            id={`tab-${tab.id}`}
            aria-selected={activeTab === index}
            aria-controls={`panel-${tab.id}`}
            tabIndex={activeTab === index ? 0 : -1}
            onClick={() => setActiveTab(index)}
            onKeyDown={(e) => handleKeyDown(e, index)}
          >
            {tab.label}
          </button>
        ))}
      </div>

      {/* Tab Panels */}
      {tabs.map((tab, index) => (
        <div
          key={tab.id}
          role="tabpanel"
          id={`panel-${tab.id}`}
          aria-labelledby={`tab-${tab.id}`}
          hidden={activeTab !== index}
          tabIndex={0}
        >
          {tab.content}
        </div>
      ))}
    </div>
  );
}
```


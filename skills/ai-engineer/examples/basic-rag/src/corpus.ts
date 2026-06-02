// A tiny in-memory corpus. In a real system these are chunks loaded from your
// document store and indexed into a vector database (Pinecone, pgvector, etc.).
export interface Doc {
  id: string;
  text: string;
}

export const CORPUS: Doc[] = [
  {
    id: "refunds",
    text: "Refunds are processed within 5 business days to the original payment method. Customers must request a refund within 30 days of purchase.",
  },
  {
    id: "shipping",
    text: "Standard shipping takes 3 to 7 business days. Express shipping arrives in 1 to 2 business days and is available at checkout for an extra fee.",
  },
  {
    id: "warranty",
    text: "All hardware products carry a 12-month limited warranty covering manufacturing defects. The warranty does not cover accidental damage.",
  },
  {
    id: "support-hours",
    text: "Live support is available Monday to Friday, 9am to 6pm AEST. Outside those hours, submit a ticket and the team responds the next business day.",
  },
  {
    id: "account",
    text: "To reset your password, use the Forgot Password link on the sign-in page. A reset email arrives within a few minutes; check spam if it does not.",
  },
];

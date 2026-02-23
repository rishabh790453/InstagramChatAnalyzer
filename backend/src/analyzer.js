import Sentiment from 'sentiment';

const sentiment = new Sentiment();

function normalizeParticipants(participants) {
  if (!Array.isArray(participants)) {
    return [];
  }

  return participants
    .map((participant) => participant?.name)
    .filter((name) => typeof name === 'string' && name.trim().length > 0)
    .slice(0, 2);
}

function normalizeMessages(messages, supportedParticipants) {
  if (!Array.isArray(messages)) {
    return [];
  }

  return messages
    .map((item) => {
      const sender = item?.sender_name;
      const timestampMs = Number(item?.timestamp_ms);
      const content = typeof item?.content === 'string' ? item.content : null;

      if (!supportedParticipants.includes(sender) || Number.isNaN(timestampMs)) {
        return null;
      }

      return {
        sender,
        timestampMs,
        content,
      };
    })
    .filter((item) => item !== null)
    .sort((a, b) => a.timestampMs - b.timestampMs);
}

function getAverage(total, count) {
  if (count === 0) {
    return 0;
  }

  return total / count;
}

export function analyzeConversation(conversation) {
  const participants = normalizeParticipants(conversation?.participants);

  if (participants.length < 2) {
    throw new Error('Conversation must contain at least two participants.');
  }

  const [participantOne, participantTwo] = participants;
  const messages = normalizeMessages(conversation?.messages, participants);

  const messageCounts = {
    [participantOne]: 0,
    [participantTwo]: 0,
  };

  const responseBuckets = {
    [participantOne]: [],
    [participantTwo]: [],
  };

  const sentimentScoreTotals = {
    [participantOne]: 0,
    [participantTwo]: 0,
  };

  const sentimentScoreCounts = {
    [participantOne]: 0,
    [participantTwo]: 0,
  };

  for (const message of messages) {
    messageCounts[message.sender] += 1;

    if (message.content) {
      const score = sentiment.analyze(message.content).score;
      if (score !== 0) {
        sentimentScoreTotals[message.sender] += score;
        sentimentScoreCounts[message.sender] += 1;
      }
    }
  }

  for (let index = 1; index < messages.length; index += 1) {
    const previousMessage = messages[index - 1];
    const currentMessage = messages[index];

    if (previousMessage.sender !== currentMessage.sender) {
      const responseMinutes = (currentMessage.timestampMs - previousMessage.timestampMs) / 60000;
      if (responseMinutes >= 0) {
        responseBuckets[currentMessage.sender].push(responseMinutes);
      }
    }
  }

  const averageResponseMinutes = {
    [participantOne]: getAverage(
      responseBuckets[participantOne].reduce((sum, value) => sum + value, 0),
      responseBuckets[participantOne].length,
    ),
    [participantTwo]: getAverage(
      responseBuckets[participantTwo].reduce((sum, value) => sum + value, 0),
      responseBuckets[participantTwo].length,
    ),
  };

  const averageSentiment = {
    [participantOne]: getAverage(
      sentimentScoreTotals[participantOne],
      sentimentScoreCounts[participantOne],
    ),
    [participantTwo]: getAverage(
      sentimentScoreTotals[participantTwo],
      sentimentScoreCounts[participantTwo],
    ),
  };

  return {
    participants,
    totals: {
      totalMessages: messages.length,
    },
    metrics: {
      messageCounts,
      averageResponseMinutes,
      averageSentiment,
    },
  };
}
